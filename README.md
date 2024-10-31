# Nextflow Pipeline for DeepVariant

This repository contains a Nextflow pipeline for Google’s DeepVariant, optimised for execution on NCI Gadi.

## Quickstart Guide

1. <a id='retrieve-args'></a> Perform a dry run with DeepVariant Singularity image to retrieve the required arguments for the `make_examples` and `call_variants` stages: 

    ```bash
    singularity run deepvariant_1.6.1-gpu.sif run_deepvariant \
        --reads=<reads> \
        --ref=<ref> \
        --sample_name=<sample_name> \
        --model_type=<model_type> \
        --output_vcf=anything.vcf.gz \
        --dry_run=true
    ```

    - For the `make_examples` stage: Extract the arguments string starting from `--add_hp_channel`.
    - For the `call_variants` stage: Extract the arguments string starting from `--checkpoint`.

2. Edit the `pipeline_params.yml` file to include:

    - `samples`:  a list of samples, where each sample includes the sample name and BAM file path (ensure corresponding .bai are in the same directory). The pipeline is capable of processing multiple samples in parallel.
    - `ref`: path to the reference FASTA (ensure corresponding .fai is in the same directory).
    - `output_dir`: directory path to save output files.
    - `container_path`: path to DeepVariant Singularity image
    - `make_examples_args`, `call_variants_args` : arguments retrieved in [step 1](#retrieve-args).
    - `nci_project`, `nci_storage` : NCI project and storage

3. Update `nextflow.config` to match the resource requirements for each stage of the pipeline. For NCI Gadi, it is recommended to adjust only `time` and `disk` (i.e. jobfs) parameters based on the size of the datasets used.

4. Run the pipeline with the following command:
    ```bash
    nextflow run main.nf -params-file pipeline_params.yml
    ```

    Note: Additional Nextflow options can be included (e.g., `-resume` to resume from a previously paused/interrupted run)

5. For each sample, output files will be stored in the directory `output_dir/sample_name`.