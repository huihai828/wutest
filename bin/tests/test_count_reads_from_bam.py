import pytest
from pathlib import Path
from bin.count_reads_from_bam import *



@pytest.fixture
def bed_noninteger():
    return Path('test_data/test_1.bed.gz')

@pytest.fixture
def bed_wrongcols():
    return Path('test_data/test_2.bed.gz')

@pytest.fixture
def bed_wrongext():
    return Path('test_data/test_3.bad.gz')

@pytest.fixture
def bed_correct():
    return Path('test_data/test_4.bed.gz')

@pytest.fixture
def bam_file():
    return Path('test_data/sorted_mt.bam')



def assert_bed_item(bed_item, chrom, chromStart, chromEnd, name, score, strand):
    """Test if field values of a bed item read from bed file are all correct"""

    if (
        bed_item['chrom'] == chrom
        and bed_item['chromStart'] == chromStart
        and bed_item['chromEnd'] == chromEnd
        and bed_item['name'] == name
        and bed_item['score'] == score
        and bed_item['strand'] == strand
    ):
        assert True
    else:
        assert False


def test_bed_format_noninteger(bed_noninteger):
    """Test exception when there is noninteger in columns of 'chromStart', 'chromEnd' and 'score'"""

    with pytest.raises(Exception, match='There is noninteger'):
        with BedReader(bed_noninteger) as bed_reader:
            for entry in bed_reader.read():
                print(entry)


def test_bed_format_wrongcols(bed_wrongcols):
    """Test exception if the numbers of columns are the same across BED items"""

    with pytest.raises(Exception, match='The number of columns is inconsistent'):
        with BedReader(bed_wrongcols) as bed_reader:
            for entry in bed_reader.read():
                print(entry)


def test_bed_format_wrongext(bed_wrongext):
    """Test exception when a BED file has wrong extension"""

    with pytest.raises(Exception, match='is not a proper BED file'):
        with BedReader(bed_wrongext) as bed_reader:
            for entry in bed_reader.read():
                print(entry)


def test_bed_format_correct(bed_correct):
    """Test if all bed items are read correctly when BED file format is correct"""

    with BedReader(bed_correct) as bed_reader:
        data = []
        for entry in bed_reader.read():
            data.append(entry)

        assert_bed_item(data[0], 'chrM', 5000, 5500, 'Pos1', 0, '+')
        assert_bed_item(data[1], 'chrM', 6000, 6500, 'Pos2', 0, '+')


def test_count_reads(bam_file, bed_correct):
    """Test correctness of counting reads from BAM file on regions"""

    check_bam_index(bam_file)
    data = count_reads_for_regions(bam_file, bed_correct)
    assert data[0]['readCount'] == 15
    assert data[1]['readCount'] == 1072
