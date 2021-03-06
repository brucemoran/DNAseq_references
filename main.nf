#!/usr/bin/env nextflow

params.help = ""

if (params.help) {
  log.info ''
  log.info '-------------------------------------------------------------------'
  log.info 'NEXTFLOW: MAKE HUMAN GRCH38 REFERENCE FOR DNASEQ NEXTFLOW PIPELINES'
  log.info '-------------------------------------------------------------------'
  log.info ''
  log.info 'Usage: '
  log.info 'nextflow run main.nf'
  log.info ''
  log.info '  --version   STRING    GRCh37 or GRCh38 (default)'
  log.info '  --outDir    STRING    output directory path; NB ${params.version} dir is created therein'
  log.info '  --exometag    STRING    naming for exome outputs when supplied; tag is then used in somatic_n-of-1 and batch_somatic pipelines to select relevant exome data'
  log.info '  and either'
  log.info '  --exomebedurl     STRING      URL to exome bed file for intervals; NB assumes GRCh37'
  log.info '  or'
  log.info '  --exomebedfile     STRING      locally downloaded exome bed file for intervals; NB assumes GRCh37'
  log.info ''
  log.info ''
  exit 1
}

/* 0.0: Global Variables
*/
if(params.outDir){
  params.refDir = "${params.outDir}"
}
if(!params.outDir){
  params.refDir = "${workflow.launchDir}/${params.version}"
}

//base URL for GRCh37, 38
params.gsurl37 = "gs://gatk-legacy-bundles/b37"
params.gsurl38 = "gs://genomics-public-data/resources/broad/hg38/v0"

//lowercase version
params.versionlc = "${params.version}".toLowerCase()

/* 1.0: Download GATK4 resource bundle fasta
*/
process fasta_dl {

  publishDir path: "$params.refDir", mode: "copy"
  validExitStatus 0,1,2
  errorStrategy 'retry'
  maxRetries 3

  output:
  tuple file('*noChr.fasta'), file('*noChr.fasta.fai') into (fasta_bwa, fasta_seqza, fasta_msi, fasta_dict, fasta_2bit, fasta_exome_biall, fasta_wgs_biall)

  script:
  if( params.version == 'GRCh37' )
    """
    ##http://lh3.github.io/2017/11/13/which-human-reference-genome-to-use
    gsutil cp ${params.gsurl37}/human_g1k_v37.fasta.gz ./human_g1k_v37.fasta.gz
    gunzip -c human_g1k_v37.fasta.gz | sed 's/>chr/>/g' > human_g1k_v37.noChr.fasta
    samtools faidx human_g1k_v37.noChr.fasta
    """

  else
    """
    ##http://lh3.github.io/2017/11/13/which-human-reference-genome-to-use
    ##moved to Verily as gs bucket more reliable
    gsutil cp gs://genomics-public-data/references/GRCh38_Verily/GRCh38_Verily_v1.genome.fa ./
    cat GRCh38_Verily_v1.genome.fa | sed 's/>chr/>/g' > GRCh38_Verily_v1.genome.noChr.fasta
    samtools faidx GRCh38_Verily_v1.genome.noChr.fasta
    """
}

/* 1.1: Dictionary for fasta
*/
process dict_pr {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  tuple file(fa), file(fai) from fasta_dict

  output:
  file('*.dict') into dict_win
  tuple file(fa), file(fai), file('*.dict') into (fasta_dict_exome, fasta_dict_wgs, fasta_dict_gensiz, fasta_dict_gridss)

  """
  DICTO=\$(echo $fa | sed 's/fasta/dict/')
  picard CreateSequenceDictionary \
    R=$fa \
    O=\$DICTO
  """
}

/* 1.2: Download GATK4 resource bundle dbsnp, Mills
*/
process dbsnp_dl {

  validExitStatus 0,1,2
  errorStrategy 'retry'
  maxRetries 3

  output:
  file('*.vcf') into vcf_tabix
  file('KG_phase1.snps.high_confidence.*.vcf') into ascatloci

  when:
  !params.nodbsnp

  script:
  if( params.version == 'GRCh37' )
    """
    gsutil cp ${params.gsurl37}/1000G_phase1.snps.high_confidence.b37.vcf.gz ./KG_phase1.snps.high_confidence.b37.vcf.gz
    gsutil cp ${params.gsurl37}/dbsnp_138.b37.vcf.gz ./dbsnp_138.b37.vcf.gz
    gsutil cp ${params.gsurl37}/hapmap_3.3.b37.vcf.gz ./hapmap_3.3.b37.vcf.gz
    gsutil cp ${params.gsurl37}/1000G_omni2.5.b37.vcf.gz ./KG_omni2.5.b37.vcf.gz
    gsutil cp ${params.gsurl37}/Mills_and_1000G_gold_standard.indels.b37.vcf.gz ./Mills_KG_gold.indels.b37.vcf.gz

    gunzip -cd dbsnp_138.b37.vcf.gz | sed 's/chr//g' > dbsnp_138.b37.vcf
    gunzip -cd hapmap_3.3.b37.vcf.gz | sed 's/chr//g' > hapmap_3.3.b37.sites.vcf
    gunzip -cd KG_omni2.5.b37.vcf.gz | sed 's/chr//g' > KG_omni2.5.b37.vcf
    gunzip -cd KG_phase1.snps.high_confidence.b37.vcf.gz | sed 's/chr//g' > KG_phase1.snps.high_confidence.b37.vcf
    gunzip -cd Mills_KG_gold.indels.b37.vcf.gz | sed 's/chr//g' > Mills_KG_gold.indels.b37.vcf
    """
  else
    """
    gsutil cp gs://genomics-public-data/cwl-examples/gdc-dnaseq-cwl/input/dbsnp_144.hg38.vcf.gz ./dbsnp_144.hg38.vcf.gz
    gsutil cp ${params.gsurl38}/1000G_phase1.snps.high_confidence.hg38.vcf.gz ./KG_phase1.snps.high_confidence.hg38.vcf.gz
    gsutil cp ${params.gsurl38}/Homo_sapiens_assembly38.dbsnp138.vcf ./Homo_sapiens_assembly38.dbsnp138.vcf
    gsutil cp ${params.gsurl38}/hapmap_3.3.hg38.vcf.gz ./hapmap_3.3.hg38.vcf.gz
    gsutil cp ${params.gsurl38}/1000G_omni2.5.hg38.vcf.gz ./KG_omni2.5.hg38.vcf.gz
    gsutil cp ${params.gsurl38}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz ./Mills_KG_gold.indels.hg38.vcf.gz

    gunzip -cd dbsnp_144.hg38.vcf.gz | sed 's/chr//g' > dbsnp_144.hg38.vcf
    gunzip -cd hapmap_3.3.hg38.vcf.gz | sed 's/chr//g' > hapmap_3.3.hg38.vcf
    gunzip -cd KG_omni2.5.hg38.vcf.gz | sed 's/chr//g' > KG_omni2.5.hg38.vcf
    gunzip -cd KG_phase1.snps.high_confidence.hg38.vcf.gz | sed 's/chr//g' > KG_phase1.snps.high_confidence.hg38.vcf
    gunzip -cd Mills_KG_gold.indels.hg38.vcf.gz | sed 's/chr//g' > Mills_KG_gold.indels.hg38.vcf
    """
}

/* 1.3: KG ASCAT loci
*/
process ascat_loci {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  file(vcf) from ascatloci

  output:
  file('*loci') into complete_ascat

  script:
  """
  LOCIFILE=\$(echo $vcf | sed 's/vcf/maf0.3.loci/')
  cat $vcf | \
  perl -ane '@s=split(/[=\\;]/,\$F[7]);if(\$s[3]>0.3){print "\$F[0]\\t\$F[1]\\n";}' > \$LOCIFILE
  """
}

/* 2.0: Fasta processing
*/
process bwa_index {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  tuple file(fa), file(fai) from fasta_bwa

  output:
  file('*') into complete_bwa

  script:
  """
  ##https://gatkforums.broadinstitute.org/gatk/discussion/2798/howto-prepare-a-reference-for-use-with-bwa-and-gatk
  bwa index -a bwtsw $fa
  """
}

/* 2.1: Dict processing
*/
process dict_pr2 {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  file(win_dict) from dict_win

  output:
  file('*') into complete_dict

  script:
  """
  perl -ane 'if(\$F[0]=~m/SQ\$/){@sc=split(/:/,\$F[1]);@ss=split(/:/,\$F[2]); if(\$sc[1]!~m/[GLMT]/){ print "\$sc[1]\\t\$ss[1]\\n";}}' $win_dict > seq.dict.chr-size

  bedtools makewindows -g seq.dict.chr-size -w 35000000 | perl -ane 'if(\$F[1]==0){\$F[1]++;};print "\$F[0]:\$F[1]-\$F[2]\n";' > 35MB-window.bed
  """
}

/* 3.0: Exome bed file and liftOver
*/
if(params.exomebedfile && params.exomebedurl){
  Channel.from("Please only specify --exomebedurl or --exomebedfile!\nN.B. that subsquent runs using -resume can be used to add further -exomebedurl or --exomebedfile").println { it }
}
if(params.exomebedfile && params.exomebedurl){
  exit 147
}

//set exometag
if(!params.exometag){
  if(params.exomebedurl) {
    params.exometag = "${params.exomebedurl}".split("\\.")[0]
  }
  if(params.exomebedfile) {
    params.exometag = "${params.exomebedfile}".split("\\.")[0]
  }
}

if(params.exomebedurl){
  process exome_url {

    publishDir path: "$params.refDir/exome", mode: "copy"

    output:
    file("${params.exometag}.url.bed") into exome_bed

    script:
    """
    ##download URL
    echo "Exome bed used here is from:" > README.${params.exometag}.url.bed
    echo ${params.exomebedurl} >> README.${params.exometag}.url.bed

    wget ${params.exomebedurl}
    if [[ ${params.exomebedurl} =~ zip\$ ]]; then
      unzip -p *.zip > ${params.exometag}.url.bed
    elif [[ ${params.exomebedurl} =~ bed\$ ]]; then

      ##remove any non-chr, coord lines in top of file
      CHR=\$(tail -n1 ${params.exomebedurl} | perl -ane 'print \$F[0];')
      if [[ \$CHR =~ "chr" ]]; then
        perl -ane 'if(\$F[0]=~m/^chr/){print \$_;}' ${params.exomebedurl} >  ${params.exometag}.url.bed
      else
        perl -ane 'if(\$F[0]=~m/^[0-9MXY]/){print \$_;}' ${params.exomebedurl} >  ${params.exometag}.url.bed
      fi

    else
      echo "No ZIP or BED files resulting from ${params.exomebedurl}"
      echo "Please try another URL with ZIP or BED file resulting"
      exit 147
    fi
    """
  }
}

if(params.exomebedfile){
  Channel.fromPath("${params.exomebedfile}").set { exomebed_file }
  process exome_file {

    publishDir path: "$params.refDir/exome", mode: "copy"

    input:
    file(exomebedfile) from exomebed_file

    output:
    file("${params.exometag}.file.bed") into exome_bed

    script:
    """
    ##use file as input
    echo "Exome bed used here is from:" > README.${params.exometag}.file.bed
    echo $exomebedfile >> README.${params.exometag}.file.bed

    if [[ $exomebedfile =~ bed\$ ]]; then

      ##remove any non-chr, coord lines in top of file
      CHR=\$(tail -n1 $exomebedfile | perl -ane 'print \$F[0];')
      if [[ \$CHR =~ "chr" ]]; then
        perl -ane 'if(\$F[0]=~m/^chr/){print \$_;}' $exomebedfile >  ${params.exometag}.file.bed
      else
        perl -ane 'if(\$F[0]=~m/^[0-9MXY]/){print \$_;}' $exomebedfile >  ${params.exometag}.file.bed
      fi

    else
      echo "BED file $exomebedfile is not a BED file, please retry"
      exit 147
    fi
    """
  }
}

process lift_over {

  errorStrategy 'retry'
  maxRetries 3

  input:
  file(exomebed) from exome_bed

  output:
  file('*.lift.bed') into exome_bed_liftd

  script:
  """
  if [[ ${params.version} != "GRCh37" ]]; then
    wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/liftOver/hg19ToHg38.over.chain.gz
    liftOver $exomebed hg19ToHg38.over.chain.gz ${params.exometag}.lift.bed unmapped
  else
    cp $exomebed ${params.exometag}.lift.bed
  fi
  """
}

/* 3.11: Parse bed for exome
*/
process exome_bed_pr {

  publishDir path: "$params.refDir/exome", mode: "copy", pattern: "*[.interval_list,.bed]"

  input:
  tuple file(fa), file(fai), file(dict) from fasta_dict_exome
  file(exomelift) from exome_bed_liftd

  output:
  file("${params.exometag}.bed.interval_list") into complete_exome
  file("${params.exometag}.bed") into (exome_tabix, exome_biallgz)

  script:
  """
  ##must test if all chr in fasta are in exome, else manta cries
  ##must test if all regions are greater than length zero or strelka cries
  ##must test if all seq.dict chrs are in bed and only they or BedToIntervalList cries
  perl -ane 'if(\$F[1] == \$F[2]){\$F[2]++;} if(\$F[0] !~m/^chrM/){print join("\\t", @F[0..\$#F]) . "\\n";}' $exomelift | grep -v chrM | sed 's/chr//g' > tmp.bed

   grep @SQ $dict | cut -f2 | sed 's/SN://' | while read CHR; do
   TESTCHR=\$(awk -v chrs=\$CHR '\$1 == chrs' tmp.bed | wc -l)
   if [[ \$TESTCHR != 0 ]];then
    awk -v chrs=\$CHR '\$1 == chrs' tmp.bed
   fi
  done >> tmp.dict.bed

  ##always make interval list so we are in line with fasta
  picard BedToIntervalList I=tmp.dict.bed O=${params.exometag}.interval_list SD=$dict

  ##BedToIntervalList (reason unknown) makes 1bp interval to 0bp interval, replace with original
  perl -ane 'if(\$F[0]=~m/^@/){print \$_;next;} if(\$F[1] == \$F[2]){\$f=\$F[1]; \$f--; \$F[1]=\$f; print join("\\t", @F[0..\$#F]) . "\\n";} else{print \$_;}' ${params.exometag}.interval_list > ${params.exometag}.bed.interval_list

  ##output BED
  grep -v "@" ${params.exometag}.bed.interval_list | cut -f 1,2,3,5 > ${params.exometag}.bed
  """
}

/* 3.12: create bed for WGS
*/
process wgs_bed {

  publishDir path: "$params.refDir/wgs", mode: "copy"

  input:
  tuple file(fa), file(fai), file(dict) from fasta_dict_wgs

  output:
  file('wgs.bed.interval_list') into complete_wgs
  file('wgs.bed') into (wgs_tabix, wgs_fasta_biallgz)

  script:
  """
  ##WGS intervals = 1-LN for each chr
  grep @SQ $dict | cut -f 2,3 | perl -ane '\$chr=\$F[0];\$chr=~s/SN://;\$end=\$F[1];\$end=~s/LN://;print "\$chr\\t0\\t\$end\\n";' > tmp.wgs.dict.bed

  ##always make interval list so we are in line with fasta
  picard BedToIntervalList I=tmp.wgs.dict.bed O=wgs.bed.interval_list SD=$dict

  ##output BED
  grep -v "@" wgs.bed.interval_list | cut -f 1,2,3,5 > wgs.bed
  """
}

/* 3.2: Tabix those requiring tabixing
*/
wgs_tabix.concat(exome_tabix).set { bint_tabix }
process tabix_files {

  publishDir path: "$params.refDir/exome", mode: "copy", pattern: "${params.exometag}*"
  publishDir path: "$params.refDir/wgs", mode: "copy", pattern: "wgs*"

  input:
  file(bed) from bint_tabix

  output:
  tuple file("${bed}.gz"), file("${bed}.gz.tbi") into complete_tabix

  script:
  """
  ##tabix
  bgzip $bed
  tabix $bed".gz"
  """
}

/* 3.31: Create Mutect2 af-only-gnomad file
*/
process exome_biall {

  publishDir path: "$params.refDir/exome", mode: "copy"

  input:
  file(exomebed) from exome_biallgz
  tuple file(fasta), file(fai) from fasta_exome_biall

  output:
  tuple file('af-only-gnomad.*.noChr.vcf.gz'), file('af-only-gnomad.*.noChr.vcf.gz.tbi') into exome_biallelicgz
  file('exome.biall.bed') into pcgrtoml_exome

  script:
  """
  cut -f 1,2,3 $exomebed > exome.biall.bed

  if [[ ${params.version} == "GRCh37" ]];then

    gsutil cp gs://gatk-best-practices/somatic-b37/af-only-gnomad.raw.sites.vcf ./
    bgzip af-only-gnomad.raw.sites.vcf
    tabix af-only-gnomad.raw.sites.vcf.gz
    gunzip -c af-only-gnomad.raw.sites.vcf.gz |
    bcftools view -R exome.biall.bed af-only-gnomad.raw.sites.vcf.gz | bcftools sort -T '.' > af-only-gnomad.exomerh.hg19.noChr.vcf
    perl ${workflow.projectDir}/bin/reheader_vcf_fai.pl af-only-gnomad.exomerh.hg19.noChr.vcf $fai > af-only-gnomad.${params.exometag}.hg19.noChr.vcf
    bgzip af-only-gnomad.${params.exometag}.hg19.noChr.vcf
    tabix af-only-gnomad.${params.exometag}.hg19.noChr.vcf.gz

  else

    gsutil cp gs://gatk-best-practices/somatic-hg38/af-only-gnomad.hg38.vcf.gz ./
    gunzip -c af-only-gnomad.hg38.vcf.gz | sed 's/chr//' | bgzip > af-only-gnomad.hg38.noChr.vcf.gz
    tabix af-only-gnomad.hg38.noChr.vcf.gz
    bcftools view -R exome.biall.bed af-only-gnomad.hg38.noChr.vcf.gz | bcftools sort -T '.' > af-only-gnomad.exomerh.hg38.noChr.vcf
    perl ${workflow.projectDir}/bin/reheader_vcf_fai.pl af-only-gnomad.exomerh.hg38.noChr.vcf $fai > af-only-gnomad.${params.exometag}.hg38.noChr.vcf
    bgzip af-only-gnomad.${params.exometag}.hg38.noChr.vcf
    tabix af-only-gnomad.${params.exometag}.hg38.noChr.vcf.gz
  fi
  """
}

/* 3.32: Create Mutect2 af-only-gnomad file
*/
process wgs_biall {

  publishDir path: "$params.refDir/wgs", mode: "copy"

  errorStrategy 'retry'
  maxRetries 3
  label 'half_cpu_mem'

  input:
  file(wgsbed) from wgs_fasta_biallgz
  tuple file(fasta), file(fai) from fasta_wgs_biall

  output:
  tuple file('af-only-gnomad.wgs.*.noChr.vcf.gz'), file('af-only-gnomad.wgs.*.noChr.vcf.gz.tbi') into wgs_biallelicgz
  file('wgs.biall.bed') into pcgrtoml_wgs

  script:
  """
  cut -f 1,2,3 $wgsbed > wgs.biall.bed

  if [[ ${params.version} == "GRCh37" ]];then

    gsutil cp gs://gatk-best-practices/somatic-b37/af-only-gnomad.raw.sites.vcf ./
    bgzip af-only-gnomad.raw.sites.vcf
    tabix af-only-gnomad.raw.sites.vcf.gz
    bcftools view -R wgs.biall.bed af-only-gnomad.raw.sites.vcf.gz | bcftools sort -T '.' > af-only-gnomad.wgsh.hg19.noChr.vcf
    perl ${workflow.projectDir}/bin/reheader_vcf_fai.pl af-only-gnomad.wgsh.hg19.noChr.vcf $fai > af-only-gnomad.wgs.hg19.noChr.vcf
    bgzip af-only-gnomad.wgs.hg19.noChr.vcf
    tabix af-only-gnomad.wgs.hg19.noChr.vcf.gz

  else

    gsutil cp gs://gatk-best-practices/somatic-hg38/af-only-gnomad.hg38.vcf.gz ./
    gunzip -c af-only-gnomad.hg38.vcf.gz | sed 's/chr//' | bgzip > af-only-gnomad.hg38.noChr.vcf.gz
    tabix af-only-gnomad.hg38.noChr.vcf.gz

    bcftools view -R wgs.biall.bed af-only-gnomad.hg38.noChr.vcf.gz | bcftools sort -T '.' > af-only-gnomad.wgsh.hg38.noChr.vcf
    perl ${workflow.projectDir}/bin/reheader_vcf_fai.pl af-only-gnomad.wgsh.hg38.noChr.vcf $fai > af-only-gnomad.wgs.hg38.noChr.vcf
    bgzip af-only-gnomad.wgs.hg38.noChr.vcf
    tabix af-only-gnomad.wgs.hg38.noChr.vcf.gz
  fi
  """
}

/* 4.0 Index various VCFs
*/
process indexfeature_files {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  file(tbtbx) from vcf_tabix.flatten()

  output:
  file('*') into indexfeatured

  script:
  """
  bgzip $tbtbx
  gatk IndexFeatureFile -F $tbtbx".gz"
  """
}

/* 5.0: Sequenza GC bias
*/
process seqnza {

  publishDir path: "$params.refDir", mode: "copy"

  input:
  set file(fa), file(fai) from fasta_seqza

  output:
  file('*') into sequenzaout

  script:
  """
  GENOMEGC50GZ=\$(echo $fa | sed -r 's/.fasta/.gc50Base.txt.gz/')
  sequenza−utils.py GC-windows −w 50 $fa | gzip > \$GENOMEGC50GZ
  """
}

/* 6.0: MSIsensor microsatellites
*/
process msisen {

  publishDir "$params.refDir", mode: "copy"

  input:
  set file(fa), file(fai) from fasta_msi

  output:
  file('*') into completedmsisensor

  script:
  """
  msisensor scan -d $fa -o msisensor_microsatellites.list
  """
}

/* 7.0: PCGR/CPSR data bundle
*/
process pcgr_data {
  publishDir "$params.refDir/pcgr", mode: "copy", pattern: "data"

  errorStrategy 'retry'
  maxRetries 3

  output:
  file('data') into completedpcgrdb
  file("data/${params.versionlc}/.vep/") into pcgrdbvep
  file("data/${params.versionlc}/RELEASE_NOTES") into pcgrreleasenotes
  file("data/${params.versionlc}/pcgr_configuration_default.toml") into pcgrtoml

  when:
  !params.nopcgr

  script:
  if( params.version == "GRCh37" )
    """
    wget ${params.pcgrURL37}
    tar -xf *.tgz
    rm -rf *.tgz
    """
  else
    """
    wget ${params.pcgrURL38}
    tar -xf *.tgz
    rm -rf *.tgz
    """
}
//
// process pcgr_save {
//
//   publishDir "$params.refDir/pcgr", mode: "copy"
//
//   input:
//   file(data) from completedpcgrdb
//
//   output:
//   file('data/') into savepcgrdb
//
//   script:
//   """
//   """
// }

process pcgr_toml {

  publishDir "$params.refDir/pcgr/data/${params.versionlc}", mode: "copy"

  input:
  file(toml) from pcgrtoml
  file(exomebed) from pcgrtoml_exome
  file(wgsbed) from pcgrtoml_wgs

  output:
  file("pcgr_configuration_${params.exometag}.toml") into pcgrtomld

  script:
  """
  ##calculate exome size in MB
  bedtools merge -i $exomebed > exome.biall.merge.bed
  EMB=\$(echo -n \$(( \$(awk '{s+=\$3-\$2}END{print s}' exome.biall.merge.bed) / 1000000 )))
  WMB=\$(echo -n \$(( \$(awk '{s+=\$3-\$2}END{print s}' $wgsbed) / 1000000 )))
  export EMB WMB;

  ##perl to parse standard toml config and output ours
  perl -ane 'if((\$F[0]=~m/^tmb_intermediate_limit/) || (\$F[0]=~m/^target_size_mb/)){
    next;
  }
  if(\$F[0]=~m/^\\[mutational_burden/) {
    print "[mutational_burden]\\ntmb_intermediate_limit = 10\\ntarget_size_mb = \$ENV{'EMB'}\\n";
  }
  else { print \$_; }' $toml > pcgr_configuration_${params.exometag}.toml

  perl -ane 'if((\$F[0]=~m/^tmb_intermediate_limit/) || (\$F[0]=~m/^target_size_mb/)){
    next;
  }
  if(\$F[0]=~m/^\\[mutational_burden/) {
    print "[mutational_burden]\\ntmb_intermediate_limit = 10\\ntarget_size_mb = \$ENV{'WMB'}\\n";
  }
  else { print \$_; }' $toml > pcgr_configuration_wgs.toml
  """
}

/* 3.6: PCGR/CPSR VEP cache
*/
process vepdb {

  publishDir "$params.refDir/pcgr/data/${params.versionlc}", mode: "copy"

  input:
  file(releasenotes) from pcgrreleasenotes
  file(pcgrdbvepdir) from pcgrdbvep

  output:
  file('.vep/homo_sapiens') into complete_vepdb

  """
  #! /bin/bash
  ##build VEP cache using PCGR Singularity container 'vep_install' script
  ##however PCGR installs a version of vep cache, so test that matches required version, and only install if not

  ##variables for install and test
  VEP_INSTALL=\$(find /opt/miniconda/envs/somatic_exome_n-of-1/share/*/vep_install)
  VEP_VERSION=\$(cat $releasenotes | perl -ane 'if(\$F[0] eq "VEP"){@s=split(/\\./,\$F[5]); \$v=\$s[0]; \$v=~s/v//; print \$v;}')

  ls $pcgrdbvepdir/homo_sapiens/ | cut -d "_" -f 1 > test.match
  if [[ \$(grep \$VEP_VERSION test.match | wc -l) != 1 ]];then
    \$VEP_INSTALL \
      --AUTO cf \
      --CACHE_VERSION \$VEP_VERSION \
      --CACHEDIR "./" \
      --SPECIES "homo_sapiens" \
      --ASSEMBLY ${params.version} \
      --NO_UPDATE \
      --NO_HTSLIB \
      --NO_BIOPERL \
      --NO_TEST
  fi
  """
}

/* 3.7: GenomeSize.xml for Pisces
*/
process gensizxml {

  publishDir "$params.refDir", mode: "copy"

  input:
  set file(fa), file(fai), file(dict) from fasta_dict_gensiz

  output:
  file('*') into complete_gensiz

  script:
  """
  echo "<sequenceSizes genomeName=\"$dict\">" > GenomeSize.xml
  grep "@SQ" $dict | while read LINE; do
    CONTIGNAME=\$(echo \$LINE | perl -ane '@s=split(/:/,\$F[1]);print \$s[1];' | sed 's/chr//')
    TOTALBASES=\$(echo \$LINE | perl -ane '@s=split(/:/,\$F[2]);print \$s[1];')
    MD5SUM=\$(echo \$LINE | perl -ane '@s=split(/:/,\$F[3]);print \$s[1];')
    echo -e "\\t<chromosome fileName=\"$fa\" contigName=\"\$CONTIGNAME\" totalBases=\"\$TOTALBASES\" isCircular=\"false\" md5=\"\$MD5SUM\" ploidy=\"2\" knownBases=\"\$TOTALBASES\" type=\"Chromosome\" />" >> GenomeSize.xml
  done
  echo "</sequenceSizes>" >> GenomeSize.xml
  """
}

/* 4.0: Download hartwigmedical resource bundle
*/
process hartwigmed {

  publishDir path: "$params.refDir", mode: "copy"
  validExitStatus 0,1,2
  errorStrategy 'retry'
  maxRetries 3

  input:
  tuple file(fa), file(fai), file(dict) from fasta_dict_gridss

  output:
  file('dbs') into gpldld
  file('refgenomes/human_virus') into gpldle
  file('gridss_*') into gridsspon

  script:
  if( params.version == 'GRCh37' )
    """
    curl -o gridss-purple-linx-hg19-refdata-Dec2019.tar.gz "${params.hartwigGPLURL37}"
    tar -xf gridss-purple-linx-hg19-refdata-Dec2019.tar.gz
    mv hg19/dbs/ ./dbs/
    mv hg19/refgenomes ./refgenomes

    curl -o GRIDSS_PON_37972v1.zip "${params.hartwigGRIDSSURL37}"
    unzip GRIDSS_PON_37972v1.zip

    curl -o gridss_blacklist.bed.gz https://encode-public.s3.amazonaws.com/2011/05/04/f883c6e9-3ffc-4d16-813c-4c7d852d85db/ENCFF001TDObed.gz
    cut -f 1 $fai > valid_chrs.txt
    gunzip -c gridss_blacklist.bed.gz | sed 's/chr//g' > gridss_blacklist.bed
    perl ${workflow.projectDir}/bin/exact_match_by_col.pl $fai,0 gridss_blacklist.bed,0 > gridss_blacklist.noChr.bed
    """

  // else
  //   """
  //   ##no GRCh38 yet=(
  //   """
}

process gridss {

    publishDir path: "$params.refDir", mode: "copy"

    output:
    file('gridss.properties') into gridssout

    script:
    if( params.version == 'GRCh37' )
    """
    git clone https://github.com/PapenfussLab/gridss
    mv gridss/src/main/resources/gridss.properties ./
    """

}
