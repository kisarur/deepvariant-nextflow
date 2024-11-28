# Nextflow Pipeline for DeepVariant

This repository contains a Nextflow pipeline for Google’s DeepVariant, optimised for execution on NCI Gadi.

## Quickstart Guide

1. Edit the `pipeline_params.yml` file to include:
    - `samples`:  a list of samples, where each sample includes the sample name, BAM file path (ensure corresponding .bai is in the same directory), path to an optional regions-of-interest BED file (set to `''` if not required), and the model type.
    - `ref`: path to the reference FASTA (ensure corresponding .fai is in the same directory).
    - `output_dir`: directory path to save output files.
    - `container_path`: path to DeepVariant Singularity image
    - `nci_project`, `nci_storage` : NCI project and storage

3. Update `nextflow.config` to match the resource requirements for each stage of the pipeline. For NCI Gadi, you may need to adjust only `time` and `disk` (i.e. jobfs) parameters based on the size of the datasets used (the default values are tested to be suitable for a dataset of ~115GB in size).

4. Run the pipeline with the following command:
    ```bash
    nextflow run main.nf -params-file pipeline_params.yml
    ```

    Note: Additional Nextflow options can be included (e.g., `-resume` to resume from a previously paused/interrupted run)

5. For each sample, output files will be stored in the directory `output_dir/sample_name`.