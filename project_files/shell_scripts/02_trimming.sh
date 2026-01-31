#!/bin/bash 

###############################################################################################################################################################################################
# Script: 02_trimming.sh
# Autores: Pable Pérez Rogríguez & Yixi Zhang
# Fecha: Mayo 2025
# Versión: 1.3
# Descripción: Este script automatiza el trimado de los raw_reads con trimmomatic. 
# Uso: ./02_trimming.sh [-i <input_directory>] [-o <output_directory>] [-t <PE/SE>] [-s <minimal_score>] [-l <minimal_length>] [-a <adaptadores>] [-e <nombre_entorno>] [-h] [-v]
# Repositorio Github de Trimmomatic: https://github.com/usadellab/Trimmomatic
###############################################################################################################################################################################################

# 1. Funciones de formato

print_error() { echo -e "\e[1;31m$1\e[0m"; }
print_success()  { echo -e "\e[1;32m$1\e[0m"; }

# 2. Función de ayuda para mostrar el uso
display_usage() {
  echo "Uso: $0 [-i <directorio_entrada>] [-o <directorio_salida>] [-t <PE/SE>] [-s <minimal_score>] [-l <minimal_length>] [-a <adaptadores>] [-e <nombre_entorno>] [-h] [-v]"
  echo "-i: Ruta del directorio con archivos .fastq.gz crudos"
  echo "-o: Ruta del directorio donde guardar los resultados y logs"
  echo "-t: tipo de las muetras, PE: paired-end, SE:single-end"
  echo "-s: el mínimo phred score de las bases"
  echo "-l: longitud mínimo de los reads"
  echo "-a: los adaptadores a usar"
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

while getopts ":i:o:t:s:l:a:e:hv" opt; do 
  case $opt in
    h) display_usage
       exit 0 ;;
    v) echo "$version"
       exit 0 ;;
    i) input_dir="$OPTARG" ;;
    o) output_dir="$OPTARG" ;;
    t) type="$OPTARG" ;;
    a) adapter="$OPTARG" ;;
    s) minimal_score="$OPTARG" ;;
    l) minimal_length="$OPTARG" ;;
    e) env_name="$OPTARG" ;;
    \?) print_error "--> Opción inválida: -$OPTARG" >&2
       display_usage 
       exit 2 ;;
    :) print_error "--> La opción -$OPTARG requiere un argumento." >&2
       display_usage 
       exit 3 ;;
  esac
done
# 4.1. Verificación de argumentos
if [[ -z "$input_dir" ]] || [[ -z "$output_dir" ]] || [[ -z "$type" ]] || [[ -z "$minimal_score" ]] || [[ -z "$minimal_length" ]] || [[ -z "$adapter" ]]; then
  print_error "Uno o más argumentos no introducido." >&2
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


# 4.3 Validar si el tipo de muestra
if [[ "$type" != "SE"  && "$type" != "PE" ]]; then
  print_error "--> El tipo de muestra debe ser SE o PE." >&2
  exit 8
else
  echo "--> El tipo introducido es válido."
fi

# 4.4 Validar el score mínimo. Debe ser un número entre 0 y 40.
if ! [[ "$minimal_score" =~ ^[0-9]+$ ]] ; then
  print_error "--> El minimal score introducido '$minimal_score' no es válido. Debe ser un número entero entre 0 y 40." >&2
  exit 9
elif ! [[ "$minimal_score" -ge 0 && "$minimal_score" -le 40 ]]; then
  print_error "--> El score mínimo introducido '$minimal_score' está fuera del rango. Rango: [0-40]" >&2
  exit 10
else
  echo "--> El minimal score introducido es correcto."
fi

# 4.5. Validar la longitud mínima introducido

if ! [[ "$minimal_length" =~ ^[0-9]+$ ]] ; then
  print_error "La longitud mínima introducido '$minimal_length' no es válido. Debe ser un número entero positivo"
  exit 11
elif [[ "$minimal_length" -le 0 ]]; then
  print_error "La longitud mímina introducido '$minimal_length' no es válido. Debe ser mayor que 0."
  exit 12
else 
  echo "La longitud mínima introducido es válido."
fi

# 4.6.Validar el el adaptador
num_files=$(find /data/2025/grado_biotech/pablo.perezr/proyecto_final/SRV_01/02-trimming_filtering/adapters -maxdepth 1 -type f -name "$adapter" | wc -l)
if [[ "$num_files" -eq 0 ]]; then
  print_error "--> No se encontró el archivo del adaptador." >&2
  echo "--> Mostrando los adaptdores disponibles..."
  ls /data/2025/grado_biotech/pablo.perezr/proyecto_final/SRV_01/02-trimming_filtering/adapters
  exit 13
else 
  echo "--> El archivo del adaptador encontrado."
fi

# 4.7. Validar el nombre del entorno
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

# 4.8. Validando el directorio de salida

if [[ -d "$output_dir/logs" ]]; then
  echo "--> El directorio '$output_dir/logs' ya existe. Se reutiliza."
else
  echo "--> Creando directorio de logs en '$output_dir/logs'..."
  mkdir -p "$output_dir/logs"
  echo "--> El directorio de salida y de los logs creados satisfactoriamente."
fi

# 5. Redirección de salida estándar y de error a logs
exec > >(tee "$output_dir"/logs/02_trimming.out)
exec 2> >(tee "$output_dir"/logs/02_trimming.err)

#6. Activar el entorno Conda
source ~/miniforge3/etc/profile.d/conda.sh
conda activate "${env_name}"

#7. Declaración de los varibles necesarios

input_dir_arr=($( ls "${input_dir}" )) #Genera un array numérico con los archivos 	
counter=0 #Contador de archivos
file_1=""; file_2="" #Variables vacíos que se usarán para guardar nombres de archivos

#8. Trimado con Trimmomatic. 
cd "${output_dir}"
case "$type" in 
  "PE") 
    for file in "${input_dir_arr[@]}"; do
      if [[ "$file" =~ ^SRR(.*).fastq(.*)$ ]]; then #Solo tenemos en cuenta los archivos .fastq       
	counter=$(($counter+1))       #El contador se suma 1 al encontrar un archivo .fastq
	if [[ $counter -eq 1 ]]; then #Cuando el contador es igual a 1, que indica que encontró un archivo .fastq. Dicho archivo se guarda en el variable file_1
	  file_1=$file
	  accesion_num1=$(ls "${input_dir}"/${file_1} | grep -oE 'SRR[0-9]+_1') #Obtenemos el ID de accesión y lo guardamos en el variable accesion_num1
	elif [[ $counter -eq 2 ]]; then  #Cuando el contador es igual a 2, significa que ya tenemos los archivos necesarios para hacer un trimado tipo PE
	  file_2=$file		
	  accesion_num2=$(ls "${input_dir}"/${file_2} | grep -oE 'SRR[0-9]+_2')
	  counter=0 		# Reseteamos el contador
	  echo "Comenzando el trimado para los archivos: $file_1 y $file_2"
	  trimmomatic PE -threads 8 -phred33 \
	  	      "${input_dir}"/"$file_1" "${input_dir}"/"$file_2" \
		      "${accesion_num1}"_paired.fastq.gz "${accesion_num1}"_unpaired.fastq.gz \
		      "${accesion_num2}"_paired.fastq.gz "${accesion_num2}"_unpaired.fastq.gz \
		       ILLUMINACLIP:/data/2025/grado_biotech/pablo.perezr/proyecto_final/SRV_01/02-trimming_filtering/adapters/"${adapter}":2:30:10 \
		       LEADING:3 \
		       TRAILING:3 \
		       SLIDINGWINDOW:4:"$minimal_score" \
		       MINLEN:"$minimal_length" 
	  echo "Acabado el trimado para los archivos: $file_1 y $file_2"        
	fi
      fi
    done
    rm "${output_dir}"/*unpaired*
    ;;
  "SE") 
    for file in "${input_dir_arr[@]}"; do
      if [[ "$file" =~ ^SRR(.*).fastq(.*)$ ]]; then #Solo necesitamos 1 archivo .fastq para el trimado, pues es SE.
	  accesion_num=$(ls "${input_dir}"/"$file" | grep -oE 'SRR[0-9]+_1')
	  echo "Comenzando con el trimado del archivo: $file"   
          trimmomatic SE -threads 8 -phread33 \
		      "$input_dir"/"$file" \
                      "${accesion_num}"_trimado.fastq.gz \
		      ILLUMINACLIP:/data/2025/grado_biotech/pablo.perezr/proyecto_final/SRV_01/02-trimming_filtering/adapters/"${adapter}":2:30:10 \
		      LEADING:3 \
		      TRAILING: 3 \ 
		      SLIDING_WINDOW:4:"$minimal_score" \
		      MINLEN:"$minimal_length"
	  echo "Acabado el trimado para el archivo: $file"
      fi
    done
    ;;
esac

print_success "--> Acabado el trimado para todos los archivos"

exit 0
