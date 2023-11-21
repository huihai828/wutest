//
// Filter sorted BAM file and index it using samtools
//

include { SAMTOOLS_VIEW      } from '../../modules/nf-core/samtools/view/main'
include { SAMTOOLS_INDEX     } from '../../modules/nf-core/samtools/index/main'

workflow FILTER_BAM {

    take:
    ch_bam_bai // channel: [ val(meta), [ bam ], [ bai ] ]

    main:

    ch_versions = Channel.empty()


    SAMTOOLS_VIEW (
        ch_bam_bai,
        [[:], []],
        []
    )
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW.out.versions.first())

    SAMTOOLS_INDEX ( SAMTOOLS_VIEW.out.bam )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    emit:
    bam      = SAMTOOLS_VIEW.out.bam           // channel: [ val(meta), [ bam ] ]
    bai      = SAMTOOLS_INDEX.out.bai          // channel: [ val(meta), [ bai ] ]
    csi      = SAMTOOLS_INDEX.out.csi          // channel: [ val(meta), [ csi ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

