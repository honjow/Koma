/** Identify the image bytes, independently of a URL or HTTP content type. */
export function downloadImageExtension(bytes: Uint8Array): string | undefined {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpg'
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
    bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) return 'png'
  const ascii = (start: number, length: number): string => {
    let value = ''
    for (let index = start; index < Math.min(start + length, bytes.length); index++) value += String.fromCharCode(bytes[index])
    return value
  }
  if (ascii(0, 6) === 'GIF87a' || ascii(0, 6) === 'GIF89a') return 'gif'
  if (ascii(0, 4) === 'RIFF' && ascii(8, 4) === 'WEBP') return 'webp'
  if (ascii(0, 2) === 'BM') return 'bmp'
  if (bytes.length >= 4 && ((ascii(0, 4) === 'II*\u0000') || (ascii(0, 4) === 'MM\u0000*'))) return 'tif'
  if (bytes.length >= 12 && ascii(4, 4) === 'ftyp') {
    const brands: string[] = [ascii(8, 4)]
    for (let offset = 16; offset + 4 <= bytes.length; offset += 4) brands.push(ascii(offset, 4))
    if (brands.includes('avif') || brands.includes('avis')) return 'avif'
    if (['heic', 'heix', 'hevc', 'hevx'].some((brand: string): boolean => brands.includes(brand))) return 'heic'
    if (brands.includes('mif1') || brands.includes('msf1')) return 'heif'
  }
  return undefined
}

export function downloadImagePathForBytes(path: string, bytes: Uint8Array): string {
  const extension = downloadImageExtension(bytes)
  return extension === undefined ? path : path.replace(/\.[^/.]+$/, '.' + extension)
}
