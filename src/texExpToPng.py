#!/bin/env python3

from argparse import ArgumentParser
import sys
import os

parser: ArgumentParser = ArgumentParser(description="Parse command line arguments", epilog="""
Examples: python3 texExpToPng.py --exp "E = 5 + m*c^2" --size 800 --output output.png
""")
parser.add_argument('--exp', type=str, help="Input string")
parser.add_argument('--size', type=int, help="Image size")
parser.add_argument('--output', type=str, help="Output file")


args = parser.parse_args()
print(args.exp)
print(args.size)
print(args.output)


# write latex script
latex_source = """
\\documentclass{standalone}
\\usepackage{amsmath}
\\begin{document}
    $ """ + args.exp + """ $
\\end{document}"""

with open('formula.tex', 'w') as file:
    file.write(latex_source)

os.system("latex formula.tex")

os.system("dvipng -D " + str(args.size) + " -T tight -o " + args.output + " formula.dvi")
