#!/bin/bash

######################################################################################
# Script: 00_get_raw_data.sh
# Autor: Pablo Pérez Rodríguez & Yixi Zhang
# Fecha: Mayo 2025
# Versión: 1.3
# Descripción: Obtener los archivos .fastq a partir de ID de accesión SRR dentro de un archivo .txt
# Uso: ./00_get_raw_data.sh [-i <archivo_entrada.txt>] [-o <output_dir>] [-e <nombre_ambiente>] [-h] [-v]
# Repositorio sratools: https://github.com/ncbi/sra-tools
#################################################################################################

# 1. Funciones de formato
print_error(){ echo -e "\e[1;31m$1\e[0m"; }
print_success()  { echo -e "\e[1;32m$1\e[0m"; }


# 2. Función de ayuda para mostrar el uso

display_usage() {
  echo "Uso: $0 [-i <archivo_entrada.txt>] [-o <output_dir>] [-e <nombre_entorno>] [-h] [-v] "
  echo "-i: Archivo .txt con un ID de acción SRR por línea"
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
  print_error "Debes aportar argumentos."
  display_usage
  exit 1
fi
	
while getopts ":i:o:e:hv" opt; do
    case $opt in
        i) input_file="$OPTARG" ;;
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

if [[ -z "$input_file" ]] || [[ -z "$output_dir" ]] || [[ -z "$env_name" ]]; then
  print_error "Error: Uno o más argumentos no introducidos."
  exit 4
fi

# 4.2. Validar el archivo de input
if [[ ! -f "$input_file" ]]; then
  print_error "--> El archivo de entrada '$input_file' no existe." >&2
  exit 5
elif ! [[ "$input_file" =~ ^(.*).txt$ ]]; then
  print_error "--> El archivo de entrada no tiene formato .txt." >&2
  exit 6
else
  echo "El arhivo de entrada existe y tiene el formato correcto."
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

# 4.4 Crear carpeta de salida y logs
if [[ -d "$output_dir/logs" ]]; then
    echo "--> El directorio '$output_dir/logs' ya existe. Se reutiliza."
else
    echo "--> Creando directorio de logs en '$output_dir/logs'..."
    mkdir -p "$output_dir/logs"
fi


# 5. Redirección de salida estándar y de error estándar a los archivos log
exec > >(tee "${output_dir}"/logs/00_get_raw_reads.out)
exec 2> >(tee "${output_dir}"/logs/00_get_raw_reads.err)

# 6. Activar entonrno conda
source ~/miniforge3/etc/profile.d/conda.sh
conda activate "${env_name}"

# 7. Descargar los archivos .fastq con los ID de accesión usando SRAtools

cd "$output_dir"

while read line; do
  ID="$line" 
  if [[ "$ID" =~ ^SRR[0-9]+$ ]]; then
    echo "Descargando los archivos de $ID..."
    prefetch "$ID"
    fastq-dump "$ID"
  else 
    echo "El $ID no es un ID de accesión SRA." >&2
  fi
done < "${input_file}"

print_success "--> Descarga de los archivos completados."

exit 0
  


