#!/bin/bash

#######################################################################################################################
# Script: 05_counts_alignment.sh
# Autor: Pablo Pérez Rodríguez & Yixi Zhang
# Fecha: Mayo 2025
# Versión: 1.3
# Descripción: Cuantificación de lecturas alineadas mediante FeatureCounts.
# Uso: ./05_counts_alignment.sh [-i <input_dir>] [-o <dir_salida>] [-g <archivo_gtf>] [-e <nombre_entorno>] [-h] [-v] 	
#######################################################################################################################

# 1. Funciones de formato

print_error() { echo -e "\e[1;31m$1\e[0m"; }
print_success()  { echo -e "\e[1;32m$1\e[0m"; }

# 2. Función de ayuda para mostrar el uso
display_usage() {
    echo "Uso: $0 [-i <directorio_BAMs>] [-o <directorio_salida>] [-g <anotacion_GTF>] [-e <nombre_entorno>] [-h] [-v]"
    echo "-i: Ruta al directorio con archivos .bam alineados."
    echo "-o: Ruta al directorio donde guardar los resultados y logs."
    echo "-g: Archivo GTF con anotación génica"
    echo "-e: nombre del entorno a activar"
    echo "NOTA: Para la correcta ejecución de este script es imprescindible tener descargado el gestor de paquetes Conda."
    echo "NOTA: Para la crear el entorno correcto vease README.md, también recreable desde el archivo .yml adjuntado."
    echo "-h: Muestra la ayuda"
    echo "-v: Muestra la versión del script"
}

readonly version="$0 v1.3"

# 3. Procesamiento de argumentos
if [[ "$#" -eq 0 ]]; then
  print_error "--> Error: Debes aportar argumentos."
  exit 1
fi

while getopts ":i:o:g:e:hv" opt; do
  case $opt in
    i) input_dir="$OPTARG" ;;
    o) output_dir="$OPTARG" ;;
    g) gtf_file="$OPTARG" ;;
    e) env_name="$OPTARG" ;;
    h) display_usage; exit 0 ;;
    v) echo "$version"; exit 0 ;;
    \?) print_error "--> Opción inválida: -$OPTARG" >&2
        display_usage
        exit  ;;
    :) print_error "--> La opción -$OPTARG requiere un argumento." >&2
       display_usage
       exit 3 ;;
  esac
done

# 4.1 Verificación de argumentos
if [[ -z "$input_dir" || -z "$output_dir" || -z "$gtf_file" ]]; then
  print_error "--> Uno o más argumentos no introducido."  >&2
  display_usage
  exit 4
fi

#4.2. Validar el directotio de entrada: su existencia, si está vacío o no y si contiene archivos .bam

if [ ! -d "$input_dir" ]; then 
  print_error "El directorio de entrada '$input_dir' no existe." >&2
  exit 5
else
  [ "$(ls -A $input_dir)" ]  #Un proceso subshell que hace un ls (no se printea en la pantalla)>
  if [[ "$?" -ne 0 ]]; then   #Valida el exit status del proceso anterior: si != 0 indica que f>
    print_error " --> El directorio de entrada '$input_dir' está vacío"
    exit 6
  else
    echo  "--> El directorio de entrada '$input_dir' existe y no está vacío."
  fi
fi

num_files=$(find "$input_dir" -maxdepth 1 -type f -name "*.bam" | wc -l)
if [[ "$num_files" -eq 0 ]]; then
    print_error "--> No se encontraron archivos .bam en '$input_dir'" >&2
    exit 7
else 
  echo "--> El directorio de entrada contiene archivos bam."
fi
# 4.3. Validar el archivo .gtf
if [[ ! -f "$gtf_file" ]]; then
  print_error "--> Error: El archivo GTF no existe." >&2
  exit 8
elif ! [[ "$gft_file" =~ ^(.*).gft$ ]]; then
  print_error "--> El archivo NO tiene formato .gtf" >&2
  exit 9
elif ! [[ -s "$gtf_file" ]]; then
  print_error "--> El archivo está vacío." >&2
  exit 10
else
  echo "El archivo gtf validado."
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

# 4.4. Validando el directorio de salida

if [[ -d "$output_dir/logs" ]]; then
  echo "--> El directorio '$output_dir/logs' ya existe. Se reutiliza."
else
  echo "--> Creando directorio de logs en '$output_dir/logs'..."
  mkdir -p "$output_dir/logs"
  echo "--> El directorio de salida y de los logs creados satisfactoriamente."
fi

# 5. Redirección de salida estándar y de error a logs
exec > >(tee "${output_dir}"/logs/05_counts_alignment.out)
exec 2> >(tee "${output_dir}"/logs/05_counts_alignment.err)


# 6. Activar entorno conda
source /data/2025/grado_biotech/pablo.perezr/miniforge3/etc/profile.d/conda.sh
conda activate "${env_name}"

# 7. Declaración de variables
counter=0 #Contador de archivos leídos
input_dir_arr=($( ls "${input_dir}" )) #Un array numérico con todos los archivos de un directorio

# 8. Procedimiento featureCounts
for file in "${input_dir_arr[@]}"; doç
  if [[ "$file" =~ ^(.*).bam$ ]]; then
    counter=$(($counter+1))
    echo "--> Haciendo recuendo del archivo: '$file'..."
    featureCounts -p -T 4 -a "$gtf_file" \
                  -o "$output_dir"/counts_sample_${counter}.txt \
                  "$input_dir"/"${file}"
    echo "--> Se ha realizado satisafactoriamente el recuento para el archivo: '$file'."
done

print_succsess "--> Se han realizado satisfactoriamente todos los counts"

exit 0
