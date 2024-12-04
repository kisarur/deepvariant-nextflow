# Nextflow Pipeline for DeepVariant

This repository contains a Nextflow pipeline for Google’s DeepVariant, optimised for execution on NCI Gadi.

## Quickstart Guide

1. Edit the `pipeline_params.yml` file to include:
    - `samples`:  a list of samples, where each sample includes the sample name, BAM file path (ensure corresponding .bai is in the same directory), path to an optional regions-of-interest BED file (set to `''` if not required), and the model type.
    - `ref`: path to the reference FASTA (ensure corresponding .fai is in the same directory).
    - `output_dir`: directory path to save output files.
    - `nci_project`, `nci_storage` : NCI project and storage.

3. Update `nextflow.config` to match the resource requirements for each stage of the pipeline. For NCI Gadi, you may need to adjust only `time` and `disk` (i.e. jobfs) parameters based on the size of the datasets used (the default values are tested to be suitable for a dataset of ~115GB in size).

4. Load the Nextflow module and run the pipeline using the following commands:
    ```bash
    module load nextflow/24.04.1
    nextflow run main.nf -params-file pipeline_params.yml
    ```

    Note: Additional Nextflow options can be included (e.g., `-resume` to resume from a previously paused/interrupted run)

5. For each sample, output files will be stored in the directory `output_dir/sample_name`.

## Notes  

1. It is assumed that the user has access to NCI's `if89` project (required for using DeepVariant via `module load`). If not, simply request access using this [link](https://my.nci.org.au/mancini/project/if89).

## Case Study

A case study was conducted using a ~115GB BAM alignment file from a HG002 ONT whole genome sequencing (WGS) dataset to evaluate the runtime and service unit (SU) efficiency of *deepvariant-nextflow* compared to the original DeepVariant running on a single node. The benchmarking results are summarised in the table below.

<table>
    <thead>
        <tr>
            <th>Version</th>
            <th>Gadi Resources</th>
            <th>Runtime (hh:mm:ss)</th>
            <th>SUs</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan=2>Original DeepVariant</td>
            <td><code>gpuvolta</code> (24 CPUs, 2 GPUs, 192 GB memory)</td>
            <td>05:07:21</td>
            <td>368.82</td>
        </tr>
        <tr>
            <td><code>gpuvolta</code> (48 CPUs, 4 GPUs, 384 GB memory)</td>
            <td>03:18:31</td>
            <td>476.44</td>
        </tr>
        <tr>
            <td rowspan=2><i>deepvariant-nextflow</i></td>
            <td><code>normal</code> (48 CPUs, 192 GB memory) → <code>gpuvolta</code> (12 CPUs, 1 GPU, 96 GB memory) → <code>normalbw</code> (28 CPUs, 256 GB memory) </td>
            <td>03:21:01</td>
            <td>237.33</td>
        </tr>
        <tr>
            <td><code>normalsr</code> (104 CPUs, 500 GB memory) → <code>gpuvolta</code> (12 CPUs, 1 GPU, 96 GB memory) → <code>normalbw</code> (28 CPUs, 256 GB memory) </td>
            <td>02:04:35</td>
            <td>199</td>
        </tr>
    </tbody>
</table>

### Notes
- Negligible runtime/SU values for the `DRY_RUN` stage (<1 minute/<1 SU) have been excluded from the results.
- Total queueing times, which were similar across all cases, have been omitted.

## Acknowledgments

The *deepvariant-nextflow* workflow was developed by Dr Kisaru Liyanage and Dr Matthew Downton (National Computational Infrastructure), with support from Australian BioCommons as part of the Workflow Commons project.

We thank Leah Kemp (Garvan Institute of Medical Research) for her collaboration in providing test datasets and assisting with pipeline testing.