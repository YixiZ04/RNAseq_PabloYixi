Análisis de Expresión Diferencial a partir de datos RNA-Seq con dos condiciones experimentales

# Introducción

Este trabajo ha sido creado con el objetivo de analiza archivos FASTQ provenientes de una secuenciación RNA-seq, utilizando herramientas bioinformáticas ampliamente validadas. El pipeline consta de diferentes etapas: control de calidad, filtrado, alineamiento y cuantificación de lecturas.

<p align="center">
  <img src="https://www.tgiainc.com/wp-content/uploads/2021/05/icons-05-450x450.png" alt="RNA logo" width="200"/>
</p>

# Instalación del entorno

La instalación está pensada para una arquitectura Linux x86_64. Si aún no tienes Miniforge, sigue los pasos:

```bash
wget https://github.com/conda-forge/miniforge/releases/download/24.11.3-0/Miniforge3-24.11.3-0-Linux-x86_64.sh
bash Miniforge3-24.11.3-0-Linux-x86_64.sh
```

Luego, cierra y abre la terminal. Verifica Conda con:

```bash
which conda
```

Si no deseas trabajar en el entorno base, puedes crear uno nuevo con:

```bash
conda create -n environmentYP
conda activate environmentYP
```

Instala los paquetes necesarios:

```bash
conda install -c bioconda fastqc multiqc trimmomatic hisat2 samtools subread
```

# Flujo de análisis

El análisis consta de 6 pasos principales. Se recomienda crear una carpeta para cada etapa:

---
### 0. Obtención de los raw reads a partir de ID de accesión de SRA mediante sratools 

**Script:** `00_get_raw_data.sh`

Este script permite descargar los raw reads a partir de los IDs de SRA (SRR..), uno por línea, de un archivo.txt 
Los raw datas usados pertenecen a la serie GSE236419.
**Uso** 
```bash

./00_qc_raw_reads.sh [-i <archivo_entrada.txt>] [-o <output_dir>] [-e <environment_name>] [-h] [-v]

```

Devuelve los raw_reads (.fastq) en el directorio de salida
---

### 1. Control de calidad inicial de las secuencias (Pre FastQC)

**Script:** `01_qc_raw_reads.sh`

Este script permite evaluar la calidad de los archivos `.fastq.gz` antes y después del recorte.

**Uso:**
./00_get_raw_data.sh 
```bash
./01_qc_raw_reads.sh [-i <input_dir>] [-o <output_dir>] [-e <nombre_entorno>] [-h] [-v]

```

Genera archivos `.html`, `.zip` y un informe general con MultiQC. Los registros se guardan en `logs/`.
-> Opcionalmente se pueden eliminar los `.zip` conservando únicamente los `.html` 
---

### 2. Trimado de los raw reads mediante trimmomatic

**Script:** `02_trimming.sh`

Realiza el recorte de adaptadores y secuencias de baja calidad, adaptándose a datos SE o PE.

**Uso:**

```bash
./02_trimming.sh [-i <input_directory>] [-o <output_directory>] [-t <PE/SE>] [-s <minimal_score>] [-l <minimal_length>] [-a <adaptadores>] [-e <nombre_entorno>] [-h] [-v]

```
Siendo `PE` Paired-End y `SE` Single-End

Los archivos recortados se guardan en `02-trimming_filtering/`.

---

### 3. Control de calidad posterior al Trimming (Post FastQC)

**Script:** `03_post_fastqc.sh`

Este script permite evaluar la calidad de los archivos `.fastq.gz` después del recorte.

**Uso:**

```bash
./03_post_fastqc.sh [-i <input_dir>] [-o <output_dir>] [-e <nombre_entorno>] [-h] [-v]

```

Genera archivos `.html`, `.zip` y un informe general con MultiQC. Los registros se guardan en `logs/`.
-> Opcionalmente se pueden eliminar los `.zip` conservando únicamente los `.html`
---


### 4. Alineamiento de los reads al genoma de referencia con HISAT2

**Script:** `04_reads_alignment.sh`

Alinea las lecturas al genoma de referencia utilizando HISAT2 y genera archivos `.bam`.

**Uso:**

```bash
./04_reads_alignment.sh [-i <input_directory>] [-o <output_directory>] [-f <genoma_referencia>] [-t <SE/PE>] [-p <prefijo_a_usar>] [-g <prefijo_index_genoma>] [-e <nombre_entorno>] [-h] [-v]

```
->"NOTA: Si ya tiene el genoma indexado solo introducir el prefijo del genoma indexado."
->"NOTA: Si necesita indexar el genoma, aporte el genoma de referencia y el prefijo a usar, deje la opción -g vacío, si no, no se procederá al indexado."

Usa samtools para ordenar los archivos .sam generados por hisat2, y convertirlos en archivos .bam

Genoma utilizado: Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa (https://ftp.ensembl.org/pub/release-114/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz)
Archivo anotación .gtf usado: Homo_sapiens.GRCh38.114.gtf (https://ftp.ensembl.org/pub/release-114/gtf/homo_sapiens/Homo_sapiens.GRCh38.114.gtf.gz)

---

### 5. Cuantificación con FeatureCounts

**Script:** `05_counts_alignment.sh`

Cuenta las lecturas alineadas por gen usando el archivo de anotación `.gtf`.

**Uso:**

```bash
./05_counts_alignment.sh [-i <input_dir>] [-o <dir_salida>] [-g <archivo_gtf>] [-e <nombre_entorno>] [-h] [-v]

```

Genera un archivo .txt, que almacena recuento de los reads alineados, y un summary, que guarda un resumen del conteo para cada archivo .bam.
Los archivos .txt generados son los que se usan para el análisis con DESeq2

---

### 6.Análisis de resultados con DESeq2 (Rstudio) 
**R-script:** `DESeq2_biotec.Rmd` 

Guardado en el directorio R_Notebooks. 
```bash
Recreación del entorno de R:
  . Instalación de paquetes estándares:
     - ggpubr
     - ggplot2
     - dplyr
     - tidyverse
  . Instalación de paquetes Bioconductor (requiere la instalcación del BiocManagar previo):
     - bioMart 
     - clusterProfiler
     - DESeq2 (Para realizar el análisis diferencial)
     - org.Hs.eg.db (Base de datos usado para la GOannotation)
     - AnnotationDbi
     - GO.db
     - amap
     - msigdbr (Para descargar HallMark gene set annotation)

Pipeline del análisis de los resultados:
  . Carga de los outputs de featureCounts; y de un archivo .csv con la metadata
  . Creación de un DataSet para DESeq2 con los inputs
  . Pre-filtración, que elimina las filas que contiene menos de 10 reads
  . Análisis de la expresión diferencial con DESeq2
    - Normalización y obtención de gráficos (PCA plot, clustering jerárquico, HeatMap de correlación)
    - Obtención de un archivo .csv de comparación entre las dos condiciones tomando el LowGlucose como referencia.
    - Obtención de MAplot y VulcanoPlot
  . Gene Ontology enrichment annotation con ClusterProfiler:
    - Con los genes UP_regulados: Biological Process
    - Con los genes Down_regulados: Biological Process y Celullar Component
    - Base da datos usado: org.Hs.eg.db
  . GSEA con HallMark gene set annotation:
    - La anotación se descargó con msigdbr (collection = "Homo_sapiens", category="H")
``` 


# Enlaces de interés

- fastQC: https://github.com/s-andrews/FastQC  
- multiQC: https://github.com/MultiQC/MultiQC  
- Trimmomatic: http://www.usadellab.org/cms/?page=trimmomatic  
- HISAT2: https://daehwankimlab.github.io/hisat2/  
- featureCounts: http://bioinf.wehi.edu.au/featureCounts/  
- samtools: http://www.htslib.org/

---

# Créditos

Autores: Pablo Pérez Rodríguez & Yixi Zhang  
Fecha: Junio 2025  
Programación para Bioinformática - Biotecnología Computacional (UPM)  

