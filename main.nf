#!/usr/bin/env nextflow

process DRY_RUN {

    input:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(reads), path(reads_bai), val(regions), val(model_type)

    output:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(reads), path(reads_bai), val(regions), env(make_examples_args), env(call_variants_args)

    script:
    """
    run_deepvariant \
        --reads=$reads \
        --ref=$ref \
        --sample_name=$sample_name \
        --model_type=$model_type \
        --output_vcf=anything.vcf.gz \
        --dry_run=true > commands.txt

    make_examples_args=\$(grep "/opt/deepvariant/bin/make_examples" commands.txt | awk -F'/opt/deepvariant/bin/make_examples' '{print \$2}' | sed 's/--mode calling//g' | sed 's/--ref "[^"]*"//g' | sed 's/--reads "[^"]*"//g' | sed 's/--sample_name "[^"]*"//g' | sed 's/--examples "[^"]*"//g')
    call_variants_args=\$(grep "/opt/deepvariant/bin/call_variants" commands.txt | awk -F'/opt/deepvariant/bin/call_variants' '{print \$2}' | sed 's/--outfile "[^"]*"//g' | sed 's/--examples "[^"]*"//g')
    """

}

process MAKE_EXAMPLES {

    input:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(reads), path(reads_bai), path(regions), val(make_examples_args), val(call_variants_args)

    output:
    tuple val(sample_name), path('make_examples.*.gz{,.example_info.json}'), path('make_examples_call_variant_outputs.*.gz'), val(call_variants_args)
    
    script:
    def regions_arg = regions ? "--regions ${regions}" : ""
    """
    seq 0 ${task.cpus - 1} | parallel -q --halt 2 --line-buffer make_examples \\
        --mode calling --ref "${ref}" --reads "${reads}" --sample_name "${sample_name}" ${regions_arg} --examples "make_examples.tfrecord@${task.cpus}.gz" ${make_examples_args}
    """

}

process CALL_VARIANTS {

    input:
    tuple val(sample_name), path(make_examples_out), val(make_examples_call_variant_out), val(call_variants_args)

    output:
    tuple val(sample_name), path('call_variants_output*.gz'), val(make_examples_call_variant_out)

    script:
    def matcher = make_examples_out[0].baseName =~ /^(.+)-\d{5}-of-(\d{5})$/
    def num_shards = matcher[0][2] as int
    """
    call_variants --outfile "call_variants_output.tfrecord.gz" --examples "make_examples.tfrecord@${num_shards}.gz" ${call_variants_args}
    """

}

process POSTPROCESS_VARIANTS {

    publishDir "${params.output_dir}/${sample_name}" , mode: 'copy'

    input:
    tuple path(ref), path(ref_fai)
    tuple val(sample_name), path(call_variants_out), path(make_examples_call_variant_out)

    output:
    path("${sample_name}.*")

    script:
    def matcher = make_examples_call_variant_out[0].baseName =~ /^(.+)-\d{5}-of-(\d{5})$/
    def num_shards = matcher[0][2] as int
    """
    postprocess_variants --ref "${ref}" --infile "call_variants_output.tfrecord.gz" --outfile "${sample_name}.vcf.gz" --cpus "${task.cpus}" --small_model_cvo_records "make_examples_call_variant_outputs.tfrecord@${num_shards}.gz" --sample_name "${sample_name}"
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
    ch_samples = ch_samples.map { sample_name, reads, regions, model_type ->
        def reads_bai = file("${reads}.bai")
        if (!reads_bai.exists()) {
            throw new RuntimeException("BAM index file not found for sample: ${sample_name}, expected at: ${reads_bai}")
        }
        def regions_val = regions == '' ? [] : regions
        [ sample_name, file(reads), reads_bai, regions_val, model_type ]
    }

    // Do a dry run of DeepVariant to extract the arguments for MAKE_EXAMPLES and CALL_VARIANTS stages
    DRY_RUN(ch_ref, ch_samples)

    // Run the DeepVariant pipeline in three stages
    MAKE_EXAMPLES(DRY_RUN.out) 
    CALL_VARIANTS(MAKE_EXAMPLES.out) 
    POSTPROCESS_VARIANTS(ch_ref, CALL_VARIANTS.out)

}