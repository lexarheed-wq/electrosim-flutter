"""Decode a rendered teacher QR image (requires zxing-cpp and Pillow)."""
import sys
from PIL import Image
import zxingcpp
source = Image.open(sys.argv[1]).convert('RGBA')
image = Image.alpha_composite(Image.new('RGBA', source.size, 'white'), source).convert('RGB')
# Add a quiet zone around the exact painter output, as in the QR widget.
framed = Image.new('RGB', (image.width + 80, image.height + 80), 'white')
framed.paste(image, (40, 40))
result = zxingcpp.read_barcode(framed)
if result is None:
    raise RuntimeError('Rendered QR is not decodable')
print(result.text)
