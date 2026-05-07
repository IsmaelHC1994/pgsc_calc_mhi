
### mhi - report
---

- [ ] #work mhi-wgs-prs   organize meeting after gettting last version of report + review pipeline/workflow  ⏳ 2026-05-06
	- **Report**: add methodology, do a clean text revision, add 2 identifiers at top, at the bottom right page for each page of the report
		- need Rafik requested PGS for each id
		- will need to contact and prepare script to update ica report html output 
		- will need to probably redo the HCM indicated from the 55 
	- fix percentile based on reference + patients set TO reference + single patient
	- **docker with github??**
	- docker for all container dependencies (pgscalc utils. python)
	- check the followign issue: **Warning: Failed to generate subset CSV for 16-524**

ICA: 
	- test/ prod batch
	- 55 samples 
	- container, words report in a zip 
	- table with linking (id1,id2)
	- to finalize

note down this:
```

./cag_bak/wfPGScalc/merged_array_cag_pop_a.log
./cag_bak/wfPGScalc/merged_array_cag_pop_a.pgen
./cag_bak/wfPGScalc/merged_array_cag_pop_a.pgen.zst
./cag_bak/wfPGScalc/merged_array_cag_pop_a.psam
./cag_bak/wfPGScalc/merged_array_cag_pop_a.psam.bak
./cag_bak/wfPGScalc/merged_array_cag_pop_a.pvar
./cag_bak/wfPGScalc/merged_array_cag_pop_a.pvar.zst
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_merged.bed
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_merged.bim
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_merged.fam
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_merged.log
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_merged.nosex
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_pca.eigenval
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_pca.eigenvec
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_pca.log
./cag_bak/wfPGScalc/merged_target_ref/merged_array_cag_pop_a_GRCh38_HGDP+1kGP_ALL_pca_ancestries.eigenvec
```


### ICA
---
- analysis of 55 samples [[#batches for 55 samples (oct 2025)]]
	- before, update report template with better PGS ID info extraction and plot improvements
	- resolve issue of working platform
- **documentation** -> R versions reproducible (for report; pak vs renv), versioning for nextflow, pgscalc....
- PRS second nextflow directly from a converted VCF -> for repeats of PRS with preprocessed gVCF
		- multiplesample probably seems best option, should be able to split multisample vcf in single if needed
- what about nextflow reproducibility?
- pgscalc + utils backup?
- what about the VCF chr/format issues?

**4h to complete per run avg**
11.70 iCredit ->5 
20.12 iCredit -> 10 
27.90 iCredit -> 15 
28.31 iCredit -> 15 
icredit -> 10

icredit -> 120USD -> 200CAD x64 | 

- https://ldm-icm.cac1.sh.basespace.illumina.com/analyses/12304293/files
- https://ldm-icm.cac1.sh.basespace.illumina.com/biosamples
- https://help.ica.illumina.com/command-line-interface/cli-indexcommands#icav2-projectdata
- https://ldm-icm.cac1.sh.basespace.illumina.com/analyses

pgsc-calc + qc / report MHI implementation**
---
**steps**
- screenshot the link option
- document changes - alterations to PGSCCALC make it work
- keep testing with more datasets (+ more than 1 score/vcf-dataset) 
- [x] cant probably use chain files directly integrated, but they are optional if using pgs-catalog ✅ 2025-09-26
- [x] need to solve issue with outdir ✅ 2025-09-26
- [x] docker for font ✅ 2025-09-26

https://help.ica.illumina.com/home/h-dockerrepository

**things to ponder**
see [[cag - mhi prs - illumina ICA#report]]
- [x] #work problem with PGS00...16, what happened? supposed to be the one for subset... ✅ 2025-09-24
	- is the new format function in v2.1 of pgscalc, just keep everything in the same version (2.01) until big next update... (v3?) of pgscalc.
- [x] #work improving input json ✅ 2025-09-22
	- order of options (specially liftover + hg chains)
	- find a way to have the assets be packaged already...
	- BACKUP PIPELINE!


#### ICA - generalities
---

Check the [[illumina ICA.canvas|illumina ICA]] canvas for a GUI guide.

**They work with  bundles - symlink of several things (ex you can add symlinks of DRAGEN tools)**

**PROJECTS**
- ICA: if project is grayed out -> this is because it is a bridge between basespace at ICA. Grayed out means the data is "hosted" in basespace. 

[GUI create pipeline in ICA?](https://help.ica.illumina.com/tutorials/nextflow)
Pipelines docs, including the [compute types must be passed as pod activity](https://help.connected.illumina.com/illumina-connected-analytics/project/p-flow/f-pipelines#compute-types) 
	- pod annotation - standard-large | type of compute | documentation | ram / cpu |  

- to import data manually Through interface?: [https://help.ica.illumina.com/tutorials/nextflow](https://help.ica.illumina.com/tutorials/nextflow) )
	- using CLI too works
- HPC nextflow runs with slurm -> illumina queue system
	- to adapt executor, check pod system
- docker tarball private or public upload through ICA / only for *premium*

#### CLI
---
Allowed to mount with fuse like for HPC alliance canada -> cli mounting point | fuse driver | 
- projectdata mount/unmount
- also temporary amazon ws3 link for things like  IGV that you can point out to avoid having to download files

```bash
export ica=59d5f397-c6a0-4d20-b184-3496e3ee24fb

icav2 projectdata delete --project-id $ica [fil.]
```

Dragen -> VCF with BP resolution restricted to PGS bed positions
---
check how to process generation of [wgs](https://github.com/PGScatalog/pgsc_calc/discussions/123#discussioncomment-6469422)
vcf generation. options perhaps [here](https://support.illumina.com/help/DRAGEN_Germline_OLH_1000000083701/Content/Source/Informatics/Apps/SetParameters_swBS_appDRAGGP.htm)  

**illumina support:**
sbouslama@illumina.com
jboudreau@illumina.com
dfaucher@illumina.com
ppannunzio@illumina.com

- do test dragen/ica see [[cag - mhi prs - illumina ICA#dragen-gatk]]
	- individual vcf per patient 
	- step 0  should be a way to point  out to the fastq and samples in the X run that will go to PGS (perform 2nd variant calling with the BP option) in order to launch as many times the *mhi-prs* workflow as possible

- [dragen commands](https://help.connected.illumina.com/dragen/product-guides/dragen-v4.3/dragen-dna-pipeline/small-variant-calling#gvcf-output)
- [icav2 to access data/files?](https://help.ica.illumina.com/command-line-interface/cli-indexcommands#icav2)
	- ICA CLI ([API](https://help.ica.illumina.com/command-line-interface/cli-indexcommands#icav2) privileges?) -> icav2

- We will require to force reference calls, on a subset of positions (ex. HaplotypeCaller -L snp_positions.list -ERC BP_RESOLUTION, followed by gVCF merge and joint genotyping)
- ([https://support.illumina.com/help/DRAGEN_Germline_OLH_1000000083701/Content/Source/Informatics/Apps/SetParameters_swBS_appDRAGGP.htm]

Nextflow pipelines
---

#### changes to PGSCCALC scripts
---
##### removing genotypes cache parameter

**remove genotypes cache** and adapting it to symlinks in **results** directory:
- all processes using storeDir as a pseudo-publish dir.   
##### changes to psgc script to force local work

repo: **cag**

**(codebase/cag folder) includes assets/bin scripts that should work locally and be kept as backup for main PGSCCALC-branch**
	- it is also a backup/version control repository of earlier approaches (separate 3 pipes, not modifying PGSCCALC...)

- **FILTER_VARIANTS:** force 1 cpu, mem 8000 (withName:FILTER_VARIANTS {
        cpus   = { check_max( 1     * task.attempt, 'cpus'    ) }
        memory = { check_max( 8.GB * task.attempt, 'memory'  ) }
    })

- **PLINK2_SCORE**: force threads to 1 and memory to 8000
- **INTERSECT_VARIANTS**: proncess_single to low (oom)
- NTERSECT_THINNED:  1 cpu +   memory to 6000 to avoid oom locally
- PLINK2_VCF: minimum memory to 6000 to avoid oom locally

##### required adaptations for adding QC/REPORT/ICA implementation
----

repo: branch of PGSCCALC **(PGScatalog-mhi-dev)**

- **PLINK2_VCF**: container update
- **FLAG_SAMPLES_AWK**: Container update

- **lib/WorkflowPgscCalc.groovy**  modified to allow --scorefile_folder

- **REPORT**: emit outputs
- **INPUT_CHECK**: many changes to accept a channel instead of a string  / samplesheet
- **PGSC_CALC.nf**: many changes to allow QC+report implementation

note from PGSCCALC regarding NO FILES:
```nextflow
        // let's make one, and reuse it where possible
        // see https://nextflow-io.github.io/patterns/optional-input/ which explains this odd implementation pattern
        // these dummy files need to exist for cloud executors to work OK
        optional_input = file(projectDir / "assets" / "NO_FILE", checkIfExists: true)
```


Basespace and plans questions:
---

- Basic vs advanced plans
	- premium would allow CLI upload and creating/modifying pipelines to make it work 
	- options for pgs-calc - nextflow implementation
		- collaborate to have a test premium pipeline created to be able to test it and generate a proof of concept 
		- potential issues with dependencies. to adapt nextflow.config properly for ilumina (and pods system)


- MHI status
	- We have basespace enterprise but ICA basic 
		- **cant access bundles?**
		- samplesheet dragen vcf generation for speficic samples in the run -> go through qc/pgsc/report 
	- interested in upgrade to premium as several groups have other projects (ex. microarray work Louis Filippe )

RESOURCES
---

**report docker** base images options:
- rocker/tidyverse Tags | Docker Hub - https://hub.docker.com/r/rocker/tidyverse/tags
- rocker-org/rocker-versioned2: Run current & prior versions of R using docker. rocker/r-ver, rocker/rstudio, rocker/shiny, rocker/tidyverse, and so on. - https://github.com/rocker-org/rocker-versioned2
- Package quarto - https://github.com/quarto-dev/quarto-cli/pkgs/container/quarto


nextflow tips
----
- altering the scripts themselves make nextflow redo the .command.sh. this way we can test the different labels for process requirements. Example -> changing process_low to process_single. **Making changes to base.config does not alter the .command.sh**
	- another option seems to be to manually create a withName:**PROCESS** in the base.config to set the cpu/mem that *could* override the labels for low/single... (it not always happens, unsure why)
	-  best option seems to be to edit manually the script to use whatever cpu/mem you want.



### meetings
---

#### meeting with Benjamin (late july 2025)
---
1 - eliminate my qc from pgscalc. you will have to make some changes so the vcf -> pgen conversion happens internally with their modules/local/plink2_vcf.nf, do not try to use samplesheets, make the necessary changes to pass it as i am passing to my qc step, but using their methods - our qc steps is getting removed.  

2 - adding a parameter (also on @inputForm.json ) to make the user select the scores they are interested in and generate a second, subset report and .csv table (so no changes to the current ones)
- what was discussed:
	- to show ICA-GUI in next meeting
	- fastq - vcf are still available on basespace. to see how to copy them to dev-ICA.
		- maybe test with both or only vcf - see below
	- `pgscalc workflow`
		- pgscalc current workflow works, but is a bit buggy. qc is mostly not necessary with 1 patient only vcf. to separate and create a direct workflow without qc step. 
		- **to add a GUI option to generate a subset report/score file-table from specific score ids, like the ones passed for pgscalc. `do scoring for all scores and generate report/tables with all - only subset in this last step`**
	- `ICA;DRAGEN`
		- implement score bed generation from pgscalc (pgs-ids) to retrieve several weights files and combine them in a combined bed 
		- use the combined bed to either: 
			- generate a single vcf per patient from fastq;
			- subset 30x WGS vcf that no matter what would be generated for gene-panels review, using the combined bed; however, when pos are not found, we will need to simulate the REF calls generated by for example the BP_PAIR resolution to option (`maybe PGS-CALC will eventually fix this)`  

- 2025-08-04 - 2025-08-09
	- add the pgen conversion to the end of the gvcf process pipeline?
	- add post report selection at the end
	- test gvcf conversion on ICA
	- see pod system see pod syste
	- test after the pgscalc 
	- see how to connect them together
	- finish the version without qc
	- contact sidki
	- fix new plot during pipeline (html height and width issues?) 

- `2025-07-23 -2025-07-29`
	- to test new plot auto. generation
		- see if anything else from the docx from genetic counselor should be added 
- find a way to keep the pgscalc utils required images in backup or combine then with what we have/download and keep it myself
- edit input_json for the dev pgscalc pipeline on ICA
	- remove options
	- remove qc for single VCF 
	- see how to include tbi, multiple vcf
	- add new report version
- bed_from_scores pipeline
	- rename, remove bed subsetting, use github approach, with split or not split chr, depending on gvcf. 
	- upload, test on ICA
- gvcf_subset pipe -> run_pgscalc pipe
	- test - lambdas?
- WEIRD BUGS WITH 401 TOKEN NOT AUTHORIZED (PERHAPS TOO MUCH RESOURCES CONSUMED?)
	- remove folders from failed runs
		- test locally
			- contact sidki otherwise


##### Meetings with Sidki

`2025-05-23`
ERROR ~ Cannot a find a file system provider for scheme: project
- change docker to direct URL in nf.config
- MUST CHANGE the way the scorefiles and vcf will be passed as inputs. 
	- for the vcf, either replicate the samplesheet in a process and pass the inputs as the true vcf.
		- or pass it directly and set the sampleset, format, chrom...values downstream
	- for the scorefiles, need to pass a folder directly as input to the orchestrator with all score files inside 
- the inputform must reflect the changes required.


`2025-05-02`
- branch pgs-calc. adapt main.nf -> include qc and report. test locally and then start testing 
- use small datasets first - pod system will default to 2gb at most probably.


##### Clinical meetings

`2025-05-20`
- remove - outliers from reference population / center plot to 0
- fix table headers and text in english  
- ask genetic counselor for the distribution for several scores with CaG to compare with HGDP+1KG
	**survey for which plots to use?**
		- what could be shown in the report that will be easier, a density plot (overall, no ancestries), histogram, or the risk plot with percentiles?
		- add risk arrows to density plot and histogram
		- add sentence from QRISK2 to risk plot with percentiles
- [x] #work fix report text according to feedback ✅ 2025-06-19
**TO DOCUMENT:**
- percentiles calculated using the reference population? (**YES**)


`2025-04-23`

- PGSCATALOG used IDs + date as disclaimer 
- for reporting percentiles - at some point we should generate a dataset that will also incorporate the info from previous runs (+ the ref population, ex. 1000 genomes/HGDP+1KG?)


`2025-03-27`

- asking illumina to obtain desired VCF format (force ref calls, see email with topic question regarding Dragen WGS vcf generation ) 

# nf-implementation
- PGScalc
	- #work to create a branch to mhi-prs for local dev.
	- #work 5 scores to test: HCM/DCM/BRUGADA/AF/LOWQT. see email to Stephane Lop.
- #work  (test 6 patients? Amish + lowPass vs 30x vs multiplex)  30x || LowPASS || 5x/10x with and without missingness

### APPENDIX
---

### batches for 55 samples (oct 2025)

First samples for reporting:

```bash

# issues?

# first batch, 5 samples
16-524
20-721  # HCM
24-1195
24-1441
24-1456

# second batch *10 samples*
24-1480
24-1483
24-1489
24-1491
24-1492
24-1512
24-1526
24-1529
24-1567
24-1581

# third batch (15 samples)
24-1610
24-1620
24-1778
24-1782
24-1788 # 5
24-1877
24-1897
24-1901
24-1940
24-1979 # 10
24-1981
24-1983
24-1990
24-2008
24-2078 # 15

# 4th batch (15 samples)
24-2090
24-2274
24-2281
24-2293
24-2314 # 5
24-2315
24-2316
24-2412
24-2449 
24-2457 # 10
24-2459
24-2462
24-2463
25-115
25-17 # 15

# 5th batch (10 samples)
25-178
25-276
25-299
25-336
25-348 #5
25-438
25-445
25-458
25-483
25-549 # 10
```

### gvcf conversion (github)
https://gist.github.com/ckandoth/e8d064685b5012937a75d2b7fca584c5 last update jul22

```bash

i found this project which tries to get a similar result from WGS and pgscalc.
# GOAL: Prototype a bioinformatics pipeline to calculate Polygenic Risk Scores (PRS) using WGS gVCFs.

# Let's use pgscalc (https://github.com/pgscatalog/pgsc_calc) a nextflow pipeline to calculate PRS, given PR weights and
# a multi-sample VCF. Variant allele weights can be specified either as PGS Catalog IDs (--pgs_id) and/or as custom scoring
# files (--scorefile). pgscalc can also perform liftover if scoring files use a different reference genome build than the
# input VCFs (--liftover --target_build).

# Steps below were tested on Ubuntu 24.04. But should work fine with any Linux server using bash.

# ----- #
# TOOLS #
# ----- #

# Download and install conda to help us manage our tools and dependencies.
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -bup ~/miniconda3 && rm /tmp/miniconda.sh

# Modify ~/.bashrc to load conda on login, and then exit.
cat >> ~/.bashrc << 'EOF'
# Add conda to PATH if found
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    . $HOME/miniconda3/etc/profile.d/conda.sh
fi
EOF
exit

# Log back in, accept conda TOS, update it to the latest version, and configure it to use libmamba, a faster dependency solver.
conda tos accept --channel defaults
conda update -y conda
conda config --set solver libmamba

# Use conda to install the tools we need and their dependencies.
conda create -y -n prs -c bioconda -c conda-forge -c defaults bcftools==1.20 samtools==1.20 htslib==1.20 parallel==20250622 nextflow==25.04.6

# bs (BaseSpace CLI) cannot be installed using conda, so let's just do it manually.
curl -L https://launch.basespace.illumina.com/CLI/latest/amd64-linux/bs -o $HOME/miniconda3/envs/prs/bin/bs
chmod +x $HOME/miniconda3/envs/prs/bin/bs

# Everytime we resume work on this project, we'll need to make sure we activate this conda env.
conda activate prs

# ------ #
# ASSETS #
# ------ #

# Download the recommended ancestry reference database (HGDP + 1000 Genomes in hg38) for use with pgscalc.
mkdir assets
wget -P assets https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_HGDP+1kGP_v1.tar.zst

# Make a VCF of all autosomal ancestry alleles. Add a fake sample "null_sample" for use with "bcftools merge" later.
echo -e "##fileformat=VCFv4.5\n##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tnull_sample" | bgzip > assets/HGDP+1kGP_ALL.hg38.vcf.gz
tar --zstd -xOf assets/pgsc_HGDP+1kGP_v1.tar.zst GRCh38_HGDP+1kGP_ALL.pvar.zst | zstd -d | awk 'OFS="\t" {if ($1 ~ /^[0-9]/) print "chr"$1, $2, ".", $4, $5, ".", ".", ".", "GT", "0/0"}' | bgzip >> assets/HGDP+1kGP_ALL.hg38.vcf.gz
tabix -p vcf assets/HGDP+1kGP_ALL.hg38.vcf.gz

# There are 81144432 variants in the resulting VCF. By default, pgscalc requires us to pull at least 75% of these from
# our WGS gVCFs. For folks with microarray or exome-seq variants, this is accomplished by imputation. Or they can reduce
# the "--min_overlap 0.75" parameter though the pgscalc authors recommend against it:
# https://pgsc-calc.readthedocs.io/en/latest/explanation/match.html#adjusting-min-overlap-is-a-bad-idea

# Let's choose these 11 diseases to calculate PRS for, using weights available from PGS catalog.
# PMID: 29273806, Asthma, PGS Catalog ID: PGS002727
# PMID: 30655379, Type I Diabetes, PGS Catalog ID: PGS000024
# PMID: 34594039, Type II Diabetes, PGS Catalog ID: PGS002308
# PMID: 39323095, Atrial Fibrillation, PGS Catalog ID: PGS005072
# PMID: 31152163, Chronic Kidney Disease, PGS Catalog ID: PGS002237
# PMID: 30554720, Breast Cancer, PGS Catalog ID: PGS000004
# PMID: 35915156, Coronary Heart Disease, PGS Catalog ID: PGS003446
# PMID: 34887591, Hypercholesterolemia, PGS Catalog ID: PGS000889
# PMID: 33398198, Prostate Cancer, PGS Catalog ID: PGS000662
# PMID: 38508198, BMI (Body Mass Index), PGS Catalog ID: PGS004736
# PMID: 38872215, Colorectal cancer, PGS Catalog ID: PGS004912

# Download the hg38 FASTA compatible with our hg38 data.
wget -P assets https://ilmn-dragen-giab-samples.s3.amazonaws.com/FASTA/hg38.fa
bgzip --threads 2 assets/hg38.fa && samtools faidx assets/hg38.fa.gz

# ----- #
# INPUT #
# ----- #

# For testing, we'll download some publicly available gVCFs from Illumina. But you can try your own WGS gVCFs. If you are
# starting with FASTQs then I strongly recommend Illumina's Dragen PAYG images on Azure or AWS. Here are instructions on
# how I used Azure NP10 VMs at a cost of less than $20 per sample from WGS FASTQ to genome-wide gVCFs:
# https://gist.github.com/ckandoth/f6a52ae704a170f9b67e80e0aa5d4b23

# Visit basespace.illumina.com and login. Create a free account if needed. Then visit basespace.illumina.com/s/htWXpgEKrRu6
# and click "Accept" to add the demo WGS data to your BaseSpace account. Use "bs auth" to login before using command below.

# Download WGS gVCFs generated by Dragen 4.3.13 on the GIAB Ashkenazi Jewish Trio (HG002, HG003, HG004):
mkdir data
bs list dataset --terse --project-name "TruSeq-PCRfree-HG001-HG007-10B-2-v13" --is-type "illumina.dragen.complete.v0.4.3" --filter-term "TSPF-HG002-10B-2-v13-Rep1|TSPF-HG003-10B-2-v13-Rep1|TSPF-HG004-10B-2-v13-Rep1" |\
    xargs -L1 bs contents dataset --terse --extension gvcf.gz,gvcf.gz.tbi --id |\
    xargs -L1 bs download file --no-metadata -o data --id

# -------- #
# ANALYSIS #
# -------- #

# Convert the gVCFs into VCFs with only FMT/GT, subset to Ancestry sites, trim ALT alleles, realign indels, fix ref alleles, and remove duplicates.
find data -name "*.hard-filtered.gvcf.gz" |\
    parallel -j1 --dry-run "bcftools convert --no-version --threads 1 --gvcf2vcf --fasta-ref assets/hg38.fa.gz {} |\
    bcftools annotate --no-version --threads 1 --remove QUAL,INFO,^FORMAT/GT |\
    bcftools view --no-version --threads 1 --targets-file assets/HGDP+1kGP_ALL.hg38.vcf.gz --targets-overlap 2 --trim-alt-alleles --no-update |\
    bcftools norm --no-version --threads 1 --rm-dup all --check-ref s --fasta-ref assets/hg38.fa.gz |\
    bcftools sort --output-type z --write-index=tbi --output {= s/.hard-filtered.gvcf.gz$/.pgsc.vcf.gz/ =}"

# Dragen gVCFs might use IUPAC code for some REF alleles (e.g. Y for C/T at chr13:100972571), whereas our Ancestry VCF
# uses REF allele N. This breaks bcftools merge below, so that's why we need to include "bcftools norm --check-ref s"
# in the unix pipes above. Also needed "--rm-dup all" to remove duplicate entries that can happen when using Dragen's
# targeted caller for paralogous regions or the force-genotying feature. The pipeline above takes around 1 hour to process
# a single gVCF. If you have more CPU cores, then increase the "--threads" parameters and/or the "-j" parameter for parallel.

# Merge per-sample VCFs into a multi-sample VCF with only GT fields. Use the null_sample to set GT=./. for missing variants.
mkdir msvcfs
find data -name "*.pgsc.vcf.gz" |\
    xargs bcftools merge --no-version --threads 1 --filter-logic x --merge none assets/HGDP+1kGP_ALL.hg38.vcf.gz |\
    bcftools norm --no-version --threads 1 --rm-dup all |\
    bcftools view --no-version --threads 1 --samples ^null_sample --no-update --output-type z --write-index=tbi --output msvcfs/ajtrio.pgsc.hg38.vcf.gz

# 81269802 entries are in the resulting multi-sample VCF, which is more than the 81144432 Ancestry variants. Some sites
# with different alleles are saved as separate entries. But we expect pgscatalog-match to match up variants properly:
# https://pygscatalog.readthedocs.io/en/latest/how-to/guides/match.html

# Make a CSV compatible with pgscalc:
echo -e "sampleset,path_prefix,chrom,format\najtrio,/mnt/drop/prs/msvcfs/ajtrio.pgsc.hg38,,vcf" > msvcfs/ajtrio.pgsc.csv

# Create a nextflow config to optimize pgscalc for your machine (pgsc-calc.readthedocs.io/en/latest/how-to/bigjob.html)
# The config below allows two "process_low" jobs to run in parallel on an Azure FX2ms_v2 VM (2-cores, 42 GB RAM) or one
# "process_medium" job at a time. The MATCH_VARIANTS step (process_medium) needs more RAM to handle more data. It needed
# 34 GB RAM for this trio VCF with 81M variants, and needed 102 GB RAM to handle a 336-sample VCF with 84M variants. If
# you don't have that much RAM to spare, you must split the VCF by chromosome following pgscalc docs.
cat > msvcfs/ajtrio.pgsc.config << 'EOF'
process {
    executor = 'local'
    withLabel:process_low {
        cpus   = 1
        memory = 20.GB
    }
    withLabel:process_medium {
        cpus   = 2
        memory = 40.GB
    }
}
EOF

# Run pgscalc on this VCF using the PGS Catalog IDs for diseases shortlisted earlier. Set CPUs/Mem per your machine specs.
mkdir -p pgscalc/ajtrio
nextflow -log pgscalc/ajtrio.log run pgscatalog/pgsc_calc -revision v2.1.0 -profile docker -c msvcfs/ajtrio.pgsc.config -work-dir pgscalc/nf --max_cpus 2 --max_memory 40.GB --input msvcfs/ajtrio.pgsc.csv --outdir pgscalc/ajtrio --target_build GRCh38 --pgs_id PGS002727,PGS000024,PGS002308,PGS005072,PGS002237,PGS000004,PGS003446,PGS000889,PGS000662,PGS004736,PGS004912 --run_ancestry assets/pgsc_HGDP+1kGP_v1.tar.zst

# pgscalc reports an 86.6% match between the input VCF and the HGDP+1000g variants. This is over their recommended
# "--min_overlap" of 75%. The match % to sites in each scoring file is also over 75% except for Type 1 Diabetes (52%),
# which may have sites not in the ancestry DB.

# ::TODO:: Add hg38 loci from the PGS catalog variants to improve the match % to the scoring files.


i think this case is more complex since its dealing with multiple samples and has to merge them, while our case is goign to be singel sample vcf

i want you to review, and put in a md your thoughts, asto if some extra steps here will be necassry. i think the author is right that pgscaclc will fail in the merge with thereference ancestry as the targetted vcf might end up with only 500,000 (for two scores combined, for example) instead of the 8M from the refernce. but then, how about just getting the list of variants from the reference file HGDP+1kGP_ALL.hg38.vcf.gz (i have it) and then applying the same logic we did so far with bcftools? is the author thinking of something else crucial? is there anything from this that can be used to improve our pipeline?
```

### PreQC

**optional**? add seGMM instead of check sex (since right now we need plink1.9 as there are no new versions of plink2 with check-sex ). seGMM has a container -> **EXPECTED TO BE CHECKED UPSTREAM**

```bash
# Clear the cached version
rm -rf ~/.nextflow/assets/pgscatalog/pgsc_calc

# Then run with your preferred revision
nextflow run pgscatalog/pgsc_calc -r main -profile test,singularity
# OR
nextflow run pgscatalog/pgsc_calc -r v2.0.1 -profile test,singularity
```


### CAG 2024

#### CARTAGEN POPULATION CATALOGUE:

Big excel. Filter by columns/rows depending on data dictionary.
Have to use the base questioning and suivi excels to find the correct number
AF for example has data for phase 2 (10kg) with 1 (yes) 2 (no) that changes from base to suivi (91 yes base, 161 suivi)

#### benchmarking
- First, we need to exclude the CAD/AF cases from the 29k samples of CaG
    - We consult the questions. first looking at:
        - AF: ATRIAL_FIBRILLATION_OCURRENCE (base) F_PM03_CARDIO_ATRIAL (follow up)
            - 161 cases for may 2023 questions.
        - CAD: doubts regarding the variables used/numbers. 1288 ATM.
    - Eventually, we will want to get the numbers from a more curated dataset that Guillaume will send us
- Then, for the remaining 28k or so samples (excluding those with CAD and/or AF), we will split the datasets in 10k and 18k, trying to balance as much as possible the ancestries predicted using HGDP+1KG
    - **will have to use plink2 to extract samples from the merged-dataset**
- The 10k will be put aside to use as a potential CaG reference panel. The 18k are considered controls for AF/CAD and will be added to those previously excluded cases. We can call it 19k cases-controls.
- We will calculate PGS in the 19k cases-controls using derived scores for CAD/AF (khera2018?) adjusting ancestry with PGS-calc and different reference panels:
    - CAD
        - 1KG only: finished
        - HGDP+1KG: finished
        - The 10k CaG dataset previously put aside: must be set up with bootstrap first, then .tar and .zst. finished
    - AF
        - 1KG only: finished
        - HGDP+1KG: finished
        - The 10k CaG dataset previously put aside: must be set up with bootstrap first, then .tar and .zst
- Thus, we would have 3 methods (z_mostSimilarPop, z_norm1, z_norm2) x 3 reference panels, for a total of 9 calibrated scores per disease (so 18 calibrated scores in total)
- We will perform logistic regression separating CaG according to inferred ethnicities in CaG (questions) not predictions?:
    - (EUR) known EUR cases in CaG for CAD/AF vs the rest of the CaG EUR population
    - (Non-EUR) Add the rest of Non-EUR eths. together. CAD/AF cases vs controls
    - This will generate 18 C statistics per split (EURvsEUR, Non-EURvsNon-EUR), for a total of 36 C statistics
    - Repeat this step, but using the curated ancestries that Guillaume will send us to define EUR and Non EUR populations (and potentially splitting Non-EUR further, eg. cases vs controls of only African/Moroccan ancestry…)
    - With predictions:
        - CAD:
            - EURvsEUR: finished
            - NON-EURvsNON-EUR: finished
        - AF:
            - EURvsEUR: finished
            - NON-EURvsNON-EUR: finished
- UK BIOBANK calibration method benchmark. sig pval log.reg. for non eur. work on their cluster?
- Learn how to export clinical data. Use khera2018 methodology on how to assign CAD/AF phenotype to samples [https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6128408/](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6128408/)
- Hopefully retrieve around 8,000 CAD cases (n AF?) and match around the same number of controls by age/sex. Check N per ancestry
- Calculate PGS in this case-control population to benchmark the ancestry adjustment of the 3 methods (z_mostSimilarPop, z_norm1, z_norm2) x the 2 reference populations (HGDP+1KG / 1KG)
