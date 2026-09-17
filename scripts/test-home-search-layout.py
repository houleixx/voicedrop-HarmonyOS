#!/usr/bin/env python3
"""Device regression: opening/cancelling search must not move existing content.

Run against an installed Chinese-language app with populated community and shelf:
  python3 scripts/test-home-search-layout.py --target 127.0.0.1:5557
The test changes tabs and opens/cancels empty search; it does not edit user data.
"""
import argparse
import json
import re
import subprocess
import tempfile
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--target', required=True)
parser.add_argument('--hdc', default='/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc')
args = parser.parse_args()


def hdc(*command):
    return subprocess.run([args.hdc, '-t', args.target, *command],
                          check=True, capture_output=True, text=True, timeout=30)


def flatten(node):
    attrs = node.get('attributes', {})
    if attrs.get('bounds'):
        attrs['rect'] = tuple(map(int, re.findall(r'-?\d+', attrs['bounds'])))
        yield attrs
    for child in node.get('children', []):
        yield from flatten(child)


with tempfile.TemporaryDirectory(prefix='voicedrop-search-layout-') as temporary:
    local = Path(temporary) / 'layout.json'
    remote = '/data/local/tmp/voicedrop-search-layout.json'

    def layout():
        hdc('shell', 'uitest', 'dumpLayout', '-p', remote)
        hdc('file', 'recv', remote, str(local))
        return list(flatten(json.loads(local.read_text())))

    def find(nodes, text):
        return next(node for node in nodes if node.get('text') == text)

    def click(node):
        left, top, right, bottom = node['rect']
        hdc('shell', 'uitest', 'uiInput', 'click', str((left + right) // 2), str((top + bottom) // 2))
        time.sleep(0.8)

    def check_positions(anchors, nodes, label):
        for anchor in anchors:
            actual = find(nodes, anchor['text'])['rect']
            assert actual == anchor['rect'], f'{label}: content moved {anchor["rect"]} -> {actual}'

    for page in ['VD社区', '写书']:
        click(find(layout(), page))
        nodes = layout()
        cancel = next((n for n in nodes if n.get('text') == '取消'), None)
        if cancel:
            click(cancel)
        for cycle in range(2):
            before = layout()
            search = find(before, '\uf0d1')
            # Check the first rendered content labels below the toolbar, independent
            # of font scale, screen density, and specific book/post titles.
            candidates = [n for n in before if n.get('type') == 'Text'
                          and len(n.get('text', '')) >= 4
                          and n['rect'][1] > search['rect'][3]]
            anchors = sorted(candidates, key=lambda n: (n['rect'][1], n['rect'][0]))[:2]
            assert len(anchors) == 2, f'{page}: load content before running this test'
            click(search)
            searching = layout()
            assert any(n.get('type') == 'TextInput' for n in searching), f'{page}: search did not open'
            check_positions(anchors, searching, f'{page} open')
            click(find(searching, '取消'))
            cancelled = layout()
            find(cancelled, '\uf0d1')
            check_positions(anchors, cancelled, f'{page} cancel')
            print(f'PASS {page} cycle {cycle + 1}: content bounds unchanged on open/cancel')
