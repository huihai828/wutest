#!/usr/bin/env python

import argparse
import logging
import sys
import pysam
import json
import gzip
from pathlib import Path

logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""

    parser = argparse.ArgumentParser(
        description="Count read counts from BAM file for regions in a bed file and save as a JSON file.",
        epilog="Example: python count_reads_from_bam.py --bam file.bam --bed file.bed --json output.json",
    )
    parser.add_argument(
        "--bam",
        metavar="FILE_BAM",
        type=Path,
        help="Input BAM file.",
    )
    parser.add_argument(
        "--bed",
        metavar="FILE_BED",
        type=Path,
        help="Input BED file.",
    )
    parser.add_argument(
        "--json",
        metavar="FILE_JSON",
        type=Path,
        help="Output JSON file.",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


class BedReader:
    """Read and validate BED file to generate an iterator of region items"""

    BED_COLUMNS = [
        'chrom',
        'chromStart',
        'chromEnd',
        'name',
        'score',
        'strand',
        'thickStart',
        'thickEnd',
        'itemRgb',
        'blockCount',
        'blockSizes',
        'blockStarts',
    ]

    def __init__(self, filename: Path):
        self._filename = filename   # input BED file in Path type
        self.file = None            # file handler

    def open(self):
        """
        Open BED file by checking file extensions, and return a file handler
        """
        if self._filename.name.endswith('.bed'):
            return open(self._filename, 'r')
        elif self._filename.name.endswith('.bed.gz'):
            return gzip.open(self._filename, 'rt', encoding='UTF-8')
        else:
            raise Exception(f"The given file {self._filename} is not a proper BED file!")

    def read(self):
        """
        A generator function to generate an iterator of bed items parsed from a BED file
        :return:
            - an iterator of items with each as dict: { <column_name>: <field_value> }
        """
        line = self._filter_headers()
        numcols = len(line.strip().split())   # number of columns of the first BED item
        while line.strip():
            entry = self._parse_bed_item(line)
            if len(entry) == numcols:
                yield entry
                line = self.file.readline()
            else:
                raise Exception(f"The number of columns is inconsistent at line: {line}")

    def _filter_headers(self):
        """
        Filter out possible headers of a BED file and return first item line
        """
        line = None
        for line in self.file:
            if not line.startswith(('#', 'browser', 'track')):
                break
        return line

    def _parse_bed_item(self, line):
        """
        Parse a BED item line and return an entry in dictionary type
        :return:
            - an item in dictionary as: { <column_name>: <field_value> }
        """
        fields = line.strip().split()
        columns = self.BED_COLUMNS[:len(fields)]
        entry = dict(zip(columns, fields))
        try:
            entry['chromStart'] = int(entry['chromStart'])
            entry['chromEnd'] = int(entry['chromEnd'])
            if 'score' in entry: entry['score'] = int(entry['score'])
        except ValueError:
            raise Exception(f"There is noninteger in 'chromStart', 'chromEnd', or 'score' at line: {line}")
        return entry

    def __enter__(self):
        self.file = self.open()
        return self

    def __exit__(self, exc_type, exc_value, exc_traceback):
        if self.file:
            self.file.close()


def check_bam_index(input_file_bam):
    """Check if the BAM file has corresponding index file, if not then create one"""

    with pysam.AlignmentFile(input_file_bam, 'rb') as bam_file:
        if not bam_file.has_index():
            pysam.index('/'.join(input_file_bam.parts))


def count_reads_for_regions(input_file_bam, input_file_bed):
    """
    Count reads for the regions defined in BED file
    :param:
        input_file_bam: input BAM file
        input_file_bed: input BED file
    :return:
         - a list of BED items, each item combined with its read counts in dictionary as:
            [ <item1>:{ <column_name>: <field_value> }, <item2>, ...]
    """
    data = []
    with pysam.AlignmentFile(input_file_bam, 'rb') as bam_file:
        with BedReader(input_file_bed) as bed_reader:
            for entry in bed_reader.read():
                reads = bam_file.fetch(entry['chrom'], entry['chromStart']-1, entry['chromEnd']-1)
                entry['readCount'] = sum(1 for _ in reads)
                data.append(entry)
    return data


def main(argv=None):
    """Calculate read counts from BAM file on regions and save it as JSON format."""

    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    if not args.bam.is_file():
        logger.error(f"The given input file {args.bam} was not found!")
        sys.exit(2)

    if not args.bed.is_file():
        logger.error(f"The given input file {args.bed} was not found!")
        sys.exit(2)

    try:
        check_bam_index(args.bam)
        data_count = count_reads_for_regions(args.bam, args.bed)
        with open(args.json, 'w') as file:
            json.dump(data_count, file, indent=2)
    except Exception as e:
        logger.exception(e)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())
