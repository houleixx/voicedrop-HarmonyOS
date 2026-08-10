export class ManualText {
  static readable(markdown: string): string {
    return markdown
      .replace(/^```.*$/gm, '')
      .replace(/^#{1,3}\s+/gm, '')
      .replace(/\*\*(.*?)\*\*/g, '$1')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\[([^\]]+)]\((https?:\/\/[^)]+)\)/g, '$1（$2）')
      .replace(/^\|?\s*[-:]+(?:\s*\|\s*[-:]+)+\s*\|?$/gm, '')
      .replace(/^\|\s*/gm, '')
      .replace(/\s*\|\s*$/gm, '')
      .replace(/\s*\|\s*/g, '　｜　')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }
}
