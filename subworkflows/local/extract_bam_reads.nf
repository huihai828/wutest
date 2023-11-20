//
// Extract reads from BAM file in regions and convert it to FASTA file
//

include { BEDTOOLS_INTERSECT } from '../../modules/nf-core/bedtools/intersect/main'
include { BAM_TO_FASTA       } from '../../modules/local/bam_to_fasta'

workflow EXTRACT_BAM_READS {

    take:
    ch_bam_bed // channel: [ val(meta), [ bam ], [ bed ] ]

    main:

    ch_versions = Channel.empty()


    BEDTOOLS_INTERSECT (
        ch_bam_bed,
        [[:], []]
    )
    ch_versions = ch_versions.mix(BEDTOOLS_INTERSECT.out.versions.first())

    BAM_TO_FASTA ( BEDTOOLS_INTERSECT.out.intersect )
    ch_versions = ch_versions.mix(BAM_TO_FASTA.out.versions.first())

    emit:
    fasta      = BAM_TO_FASTA.out.fasta           // channel: [ *.fasta ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

