#!/bin/bash

###########################################################################
# Script: 03_post_fastqc
# Autor: Pablo Pérez Rodríguez & Yixi Zhang
# Fecha: Mayo 2025
# Versión: 1.3
# Descripción: Control de calidad de archivos .fastq.gz con FastQC.
# Uso: ./03_post_fastqc.sh [-i <input_dir>] [-o <output_dir>] [-e <nombre_entorno>] [-h] [-v]
# Repositorio fastqc: https://github.com/s-andrews/FastQC
# Repositorio multiqc: https://github.com/MultiQC/MultiQC
###########################################################################

# 1. Funciones de formato 
print_error() { echo -e "\e[1;31m$1\e[0m"; }
print_success()  { echo -e "\e[1;32m$1\e[0m"; }
print_question() { echo -e "\e[1;33m$1\e[0m"; }


# 2. Función de ayuda para mostrar el uso 
display_usage(){
    echo "Uso: $0 [-i <directorio_entrada>] [-o <directorio_salida>] [-e <nombre_entorno>] [-h] [-v]"
    echo "-i: Ruta al directorio con archivos .fastq.gz crudos"
    echo "-o: Ruta al directorio donde guardar los resultados y logs"
    echo "-e: nombre del entorno a activar"
    echo "NOTA: Para la correcta ejecución de este script es imprescindible tener descargado el gestor de paquetes Conda."
    echo "NOTA: Para la crear el entorno correcto vease README.md, también recreable desde el archivo .yml adjuntado."
    echo "-h: Muestra la ayuda"
    echo "-v: Muestra la versión del script"
}


readonly version="$0 v1.3"

# 3. Procesamiento de argumentos
if [[ "$#" -eq 0 ]]; then
  print_error "Error: Uno o más argumentos no introducidos." >&2
  display_usage 
  exit 1
fi

while getopts ":i:o:e:hv" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        e) env_name="$OPTARG" ;;
        h) display_usage; exit 0 ;;
        v) echo "$version"; exit 0 ;;
        \?) print_error "--> Opción inválida: -$OPTARG" >&2
            display_usage
            exit 2 ;;
        :) print_error "--> La opción -$OPTARG requiere un argumento." >&2
           display_usage
            exit 3 ;;
    esac
done



# 4.1. Verificación de argumentos
if [[ -z "$input_dir" || -z "$output_dir" || -z "$env_name" ]]; then
    print_error "--> Error: Uno o más argumentos no introducidos." >&2
    display_usage
    exit 4
fi

# 4.2. Validar el directotio de entrada: su existencia, si está vacío o no y si contiene archivos .fastq
if [ ! -d "$input_dir" ]; then
  print_error "El directorio de entrada '$input_dir' no existe." >&2
  exit 5
else
  [ "$(ls -A $input_dir)" ]  #Un proceso subshell que hace un ls (no se printea en la pantalla) del directorio de entrada
  if [[ "$?" -ne 0 ]]; then   #Valida el exit status del proceso anterior: si != 0 indica que falló el proceso, ya que no existe directorio
    print_error " --> El directorio de entrada '$input_dir' está vacío"
    exit 6
  else
    echo  "--> El directorio de entrada '$input_dir' existe y no está vacío."
  fi
fi
num_files=$(find "$input_dir" -maxdepth 1 -type f -name "*.fastq.gz" | wc -l)
if [[ "$num_files" -eq 0 ]]; then
    print_error "--> No se encontraron archivos .fastq.gz en '$input_dir'" >&2
    exit 7
else
  echo "--> El directorio de entrada contiene archivos fastq."
fi

# 4.3. Validar el nombre del entorno
env_list=$(ls ~/miniforge3/envs/)
env_counter=0
for env in ${env_list[@]}; do
  if [[ "$env" == "$env_name" ]]; then
     env_counter=$(($env_counter + 1))
  fi
done

if [[ "$env_counter" -eq 0 ]]; then
  print_error "--> El entorno NO existe" >&2
  exit 7
else
  echo "--> El entorno existe."
fi

# 4.4. Crear carpeta de salida y logs
if [[ -d "$output_dir/logs" ]]; then
    echo "--> El directorio '$output_dir/logs' ya existe. Se reutiliza."
else
    echo "--> Creando directorio de logs en '$output_dir/logs'..."
    mkdir -p "$output_dir/logs"
fi



# 5. Redirección de salida estándar y de error a logs
exec > >(tee "${output_dir}"/logs/03_post_fastqcs.out)
exec 2> >(tee "${output_dir}"/logs/03_post_fastqc.err)


# 6. Activar entorno conda
source ~/miniforge3/etc/profile.d/conda.sh
conda activate "${env_name}"

# 7. Ejecutar FastQC individualmente sobre archivos en $input_dir con redirección de logs
echo "--> Ejecutando FastQC sobre los archivos en $input_dir..."
for fq in "$input_dir"/*.fastq.gz; do
    sample=$(basename "$fq" .fastq.gz)
    echo "--> Analizando $sample con FastQC..."
    fastqc "$fq" -o "$output_dir"
done
print_success "---> FastQC completado. Informes guardados en $output_dir"



# 8. Ejecutar MultiQC sobre los resultados de FastQC
print_question "--> Ejecutando MultiQC sobre los resultados de FastQC..."
multiqc "$output_dir" -o "$output_dir" 


print_success "---> Análisis completado. Informes guardados en $output_dir"




# 10. Opcional: eliminar archivos .zip y carpetas de datos innecesarios
print_question "¿Deseas eliminar los archivos .zip de FastQC y la carpeta multiqc_data? [y]es o [n]o. Solo se conservarán los HTML."
while true; do
    read del_files
    case "$del_files" in
        y)
            rm -f "${output_dir}"/*.zip
            rm -rf "${output_dir}/multiqc_data"
            print_success "--> Eliminación completada."

            print_question "¿Deseas eliminar también los informes HTML individuales de FastQC? [y] o [n]..."
            while true; do
                read del_fastqc
                case "$del_fastqc" in
                    y) rm -f "${output_dir}"/*fastqc.html ; break ;;
                    n) break ;;
                    *) print_error "Por favor responde y o n" ;;
                esac
            done
            break
            ;;
        n)
            echo -e "--> Se conservarán los archivos .zip de FastQC y la carpeta multiqc_data."
            break
            ;;
        *) print_error "Por favor responde y o n" ;;
    esac
done

