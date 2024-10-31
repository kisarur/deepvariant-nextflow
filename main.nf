#!/usr/bin/env nextflow

process MAKE_EXAMPLES {

    input:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(reads), path(reads_bai)

    output:
    tuple val(sample_name), path('*.gz{,.example_info.json}')
    
    script:
    """
    seq 0 ${task.cpus - 1} | parallel -q --halt 2 --line-buffer /opt/deepvariant/bin/make_examples \\
        --ref "${ref}" --reads "${reads}" --sample_name "${sample_name}" --examples "make_examples.tfrecord@${task.cpus}.gz" ${task.ext.args}
    """

}

process CALL_VARIANTS {

    input:
    tuple val(sample_name), path(make_examples_out)

    output:
    tuple val(sample_name), path('*.gz')

    script:
    def matcher = make_examples_out[0].baseName =~ /^(.+)-\d{5}-of-(\d{5})$/
    def num_shards = matcher[0][2] as int
    """
    /opt/deepvariant/bin/call_variants --outfile "call_variants_output.tfrecord.gz" --examples "make_examples.tfrecord@${num_shards}.gz" ${task.ext.args}
    """

}

process POSTPROCESS_VARIANTS_AND_VCF_STATS_REPORT {

    publishDir "${params.output_dir}/${sample_name}" , mode: 'copy'

    input:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(call_variants_out)

    output:
    path("${sample_name}.*")

    script:
    """
    /opt/deepvariant/bin/postprocess_variants --ref "${ref}" --infile "call_variants_output.tfrecord.gz" --outfile "${sample_name}.vcf.gz" --cpus "${task.cpus}" --sample_name "${sample_name}"
    /opt/deepvariant/bin/vcf_stats_report --input_vcf "${sample_name}.vcf.gz" --outfile_base "${sample_name}"
    """

}


workflow {

    // Create a tuple of the reference FASTA and its index file. Throw an error if the index file is not found.
    ref_fai_path = file("${params.ref}.fai")
    if (!ref_fai_path.exists()) {
        throw new RuntimeException("Reference FASTA index file not found, expected at: ${ref_fai_path}")
    }
    ch_ref = [ file(params.ref), ref_fai_path ]

    // Create a channel that holds tuples for each sample, containing the sample name, the BAM file and its index file. Throw an error if the index file is not found.
    ch_samples = Channel.of(params.samples).flatMap()
    ch_samples = ch_samples.map { sample_name, reads ->
        def reads_bai = file("${reads}.bai")
        if (!reads_bai.exists()) {
            throw new RuntimeException("BAM index file not found for sample: ${sample_name}, expected at: ${reads_bai}")
        }
        [ sample_name, file(reads), reads_bai ]
    }

    // Run the DeepVariant pipeline in three stages
    MAKE_EXAMPLES(ch_ref, ch_samples) 
    CALL_VARIANTS(MAKE_EXAMPLES.out) 
    POSTPROCESS_VARIANTS_AND_VCF_STATS_REPORT(ch_ref, CALL_VARIANTS.out)

}