version 1.0
import "Structs.wdl"

workflow BbCallPlasmids {

    meta { description: "Simple workflow to classify contigs in Borrelia burgdorferi draft assemblies." }
    parameter_meta {
        sample_id: "sample_id for the assembly we're classifying"
        input_fa: "draft assembly.fasta to be classified"
    }
    input {
        String sample_id
        File input_fa
    }
    call CallPlasmids {
        input:
            sample_id = sample_id,
            input_fa = input_fa
    }
    output {
        File renamed_fasta = CallPlasmids.renamed_fasta
        File pf32_hits = CallPlasmids.pf32_hits
        File wp_hits = CallPlasmids.wp_hits
        File best_hits_json = CallPlasmids.best_hits_json
        File best_hits_tsv = CallPlasmids.best_hits_tsv
    }
}

task CallPlasmids {
    input {
        String sample_id
        File input_fa
        RuntimeAttr? runtime_attr_override
    }
    parameter_meta {
        sample_id: "sample_id for the assembly we're classifying"
        input_fa: "draft assembly.fasta to be classified"
    }
    Int disk_size = 50 + 10 * ceil(size(input_fa, "GB"))
    command <<<
        plasmid_caller \
            -i "~{input_fa}" \
            -o "results" \
            -t 8
        mv results/*.fasta results/"~{sample_id}_renamed.fasta"
        tar -C results -czvf pf32_hits.tar.gz pf32
        tar -C results -czvf wp_hits.tar.gz wp
    >>>

    output {
        File renamed_fasta = "results/~{sample_id}_renamed.fasta"
        File pf32_hits = "pf32_hits.tar.gz"
        File wp_hits = "wp_hits.tar.gz"
        File best_hits_json = "results/summary_best_hits.json"
        File best_hits_tsv = "results/summary_best_hits.tsv"
    }
    #########################
    RuntimeAttr default_attr = object {
        cpu_cores:          8,
        mem_gb:             32,
        disk_gb:            disk_size,
        boot_disk_gb:       25,
        preemptible_tries:  0,
        max_retries:        0,
        docker:             "mjfos2r/plasmid_caller:6.0.0"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}