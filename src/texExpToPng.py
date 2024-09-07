#!/bin/env python3

import os
from argparse import ArgumentParser

parser: ArgumentParser = ArgumentParser(
    description="Parse command line arguments",
    epilog="""
Examples: python3 texExpToPng.py --exp "E = 5 + m*c^2" --size 800 --output output.png
""",
)


group = parser.add_mutually_exclusive_group(required=True)

# Add the expression argument
group.add_argument("--exp", type=str, help="Input string")

# Add the filename argument
group.add_argument(
    "-f", "--file", type=str, help="The filename containing the expression."
)


parser.add_argument("--size", type=int, help="Image size")
parser.add_argument("--output", type=str, help="Output file")


args = parser.parse_args()

print(args.file)

expression = None
if args.exp:
    expression = args.exp
elif args.file:
    with open(args.file, "r") as file:
        expression = file.read()

# write latex script
latex_source = (
    """
\\documentclass{standalone}
\\usepackage{amsmath}
\\begin{document}
    $ """
    + expression
    + """ $
\\end{document}"""
)

with open("formula.tex", "w") as file:
    file.write(latex_source)

os.system("latex formula.tex")

os.system(
    "dvipng -D " + str(args.size) + " -T tight -o " + args.output + " formula.dvi"
)
