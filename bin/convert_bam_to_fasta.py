#!/usr/bin/env python

import argparse
import logging
import sys
import pysam
from pathlib import Path

logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""

    parser = argparse.ArgumentParser(
        description="Convert a BAM file into a FASTA sequence file.",
        epilog="Example: python convert_bam_to_fasta.py file_in.bam file_out.fasta",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_BAM",
        type=Path,
        help="Input BAM file",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_FASTA",
        type=Path,
        help="Output FASTA file",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """Convert a BAM file into a FASTA sequence file"""

    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    if not args.file_in.is_file():
        logger.error(f"The given input file {args.file_in} was not found!")
        sys.exit(2)

    with pysam.AlignmentFile(args.file_in, 'rb') as bam_file:
        with open(args.file_out, 'w') as fasta_file:
            for read in bam_file.fetch(until_eof=True):
                read_id = read.query_name
                sequence = read.query_sequence
                fasta_file.write(f'>{read_id}\n{sequence}\n')



if __name__ == "__main__":
    sys.exit(main())
