#!/bin/bash

####################################################################################################################################################################################################################
#Script: 04_reads_alignment.sh
#Autores: Pablo Pérez Rodríguez & Yixi Zhang
#Fecha: Mayo 2025
#Descripción: Alinea reads de archivos .fastq a un genoma de referencia con HISAT2
#NOTA: Se ofrece la opción de indexar el genoma aportando el archivo fasta del genoma de referencia y un prefijo a usar.
#NOTA: También se oferece la opción de usar un genoma ya indexado.
#Uso: ./04_reads_alignment.sh [-i <input_directory>] [-o <output_directory>] [-f <genoma_referencia>] [-t <SE/PE>] [-p <prefijo_a_usar>] [-g <prefijo_index_genoma>] [-e <nombre_entorno>] [-h] [-v]
####################################################################################################################################################################################################################

# 1. Funciones de formato

print_error(){ echo -e "\e[1;31m$1\e[0m"; }
print_success()  { echo -e "\e[1;32m$1\e[0m"; }

# 2. Función de ayuda para mostrar el uso
display_usage(){
    echo "Uso: $0 [-i <directorio_entrada>] [-o <directorio_salida>] [-f <genoma_referencia>] [-t <SE/PE>] [-p <prefijo_a_usar] [-g <prefijo_index_genoma>] [-e <nombre_entonrno>] [-h] [-v]"
    echo "-i: Ruta al directorio con archivos .fastq.gz "
    echo "-o: Ruta al directorio donde guardar los resultados y logs"
    echo "-f: archivo fasta del genoma de referencia"
    echo "-t: tipo, Paired end (PE) o Single end (SE)"
    echo "-p: prefijo para indexar el genoma"
    echo "-g: prefijo del genoma ya indexado."
    echo "NOTA: Si ya tiene el genoma indexado solo introducir el prefijo del genoma indexado."
    echo "NOTA: Si necesita indexar el genoma, aporte el genoma de referencia y el prefijo a usar, deje la opción -g vacío, si no, no se procederá al indexado."
    echo "-e: nombre del entorno a activar."
    echo "NOTA: Para la correcta ejecución de este script es imprescindible tener descargado el gestor de paquetes Conda."
    echo "NOTA: Para la crear el entorno correcto vease README.md, también recreable desde el archivo .yml adjuntado."
    echo "-h: Muestra la ayuda"
    echo "-v: Muestra la versión del script"
}

readonly version="$0 v1.3"
#3. Procesamiento de argumentos
if [[ "$#" -eq 0 ]]; then
  print_error "--> Requiere argumentos." >&2
  display_usage
  exit 1
fi

while getopts ":i:o:f:t:p:g:e:hv" opt; do
  case $opt in
    h) display_usage
       exit 0 ;;
    v) echo "$version"
       exit 0 ;;
    i) input_dir="$OPTARG";;
    o) output_dir="$OPTARG" ;;
    f) reference_gen="$OPTARG" ;;
    t) type="$OPTARG" ;;
    p) prefix_use="$OPTARG" ;;
    g) prefix_index="$OPTARG" ;;
    e) env_name=$OPTARG ;;
    \?) print_error "--> Opción inválida: -$OPTARG" >&2 
        display_usage
        exit 2 ;;
    :) print_error "--> La opción -$OPTARG requiere un argumento." >&2
       display_usage
       exit 3 ;; 
  esac
done

# 4.1. Verificación de argumentos

if  [[ -z "$input_dir" ]] ||  [[ -z "$output_dir" ]] || [[ -z "$type" ]] || [[ -z "$env_name" ]]; then
  print_error "--> Uno o más argumentos no introducido." >&2
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
    echo "--> El directorio de entrada '$input_dir' existe y no está vacío."
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

# 4.4. Validando el nombre del entorno

env_list=$(ls ~/miniforge3/envs/)
env_counter=0
for env in ${env_list[@]}; do
  if [[ "$env" == "$env_name" ]]; then
     env_counter=$(($env_counter + 1))
  fi
done

if [[ "$env_counter" -eq 0 ]]; then
  print_error "--> El entorno NO existe" >&2
  exit 9
else
  echo "--> El entorno existe."
fi

# 4.5. Validando el directorio de salida

if [[ -d "$output_dir/logs" ]]; then
  echo "--> El directorio '$output_dir/logs' ya existe. Se reutiliza."
else
  echo "--> Creando directorio de logs en '$output_dir/logs'..."
  mkdir -p "$output_dir/logs"
  echo "--> El directorio de salida y de los logs creados satisfactoriamente."
fi



# 5. Redirección de salida estándar y de error a logs
exec > >(tee "${output_dir}"/logs/04_alignment.out)
exec 2> >(tee "${output_dir}"/logs/04_alignment.err)


#6. Activar el ambiento Conda
source ~/miniforge3/etc/profile.d/conda.sh
conda activate "${env_name}"


# 7. Validando si es necesario indexar genome

if [[ -z "$prefix_index" ]]; then
  echo "--> Hay que indexar el genoma."
  if [[ -z "$reference_gen" || -z "$prefix_use" ]]; then
    print_error "--> Error: Falta el genoma de referencia o el prefijo a usar." >&2
    exit 9
  else
    echo "--> Indexando el genoma con el prefijo introducido '$prefix_use'..."
    hisat2-build "${reference_gen}" -p 4 "$prefix_use"
    echo "--> El genome indexado satisfactoriamente."
    prefix_index="$prefix_use"
  fi
else
   echo "--> No hay que indexar genoma, se introdujo el prefijo del genoma indexado."
fi

# 8. Declaración de variables a usar
input_dir_arr=($( ls "${input_dir}" )) #Variable con todos los archivos del directorio
counter=0 #Un contador de archivos
file_1=""; file_2="" #EVariables vacíos para almacenar los archivos
aligning_time=0 # Variable para contar los veces que se hizo el alineamiento, se usa exclusivamente para el caso de PE

# 9. Alineamiento con HISAT2
cd "${output_dir}"

case "$type" in 
  "PE") 
    for file in "${input_dir_arr[@]}"; do
      if [[ "$file" =~ ^(.*).fastq(.*)$ ]] || [[ "$file" =~ ^(.*).fq(.*)$ ]]; then #Si encuentra un archivo fastq        
        counter=$(($counter+1))       #Aumenta el valor de contador
        if [[ $counter -eq 1 ]]; then #Cuando el contador es 1
          file_1=$file #Guardamos el primer archivo en el variable file_1
        elif [[ $counter -eq 2 ]]; then #Cuando el contador es 2
          file_2=$file          #Guardamos el archivo en el variable file_2
          counter=0             # Reseteamos el contador 
          aligning_time=$(($aligning_time + 1))  #Aunmenta las veces de alineamiento, este variable se usará para nombrar el archivo de salida
	  echo "Start alignment for "$file_1" and "$file_2"..."
	  hisat2 -p 4 -x "$prefix_index" \
		 -1 "${input_dir}"/"$file_1" -2 "${input_dir}"/"$file_2" \
	 	 -S sample_"${aligning_time}".sam		 
	  samtools sort -o sample_"${aligning_time}".bam sample_"${aligning_time}".sam	  
          rm sample_"${aligning_time}".sam
	  echo "Alineado los archivos $file_1 y $file_2. El resultado es sample_${aligning_time}.bam."        
        fi
      fi
    done
    ;;
  "SE") 
    for file in "${input_dir_arr[@]}"; do
      if [[ "$file" =~ ^(.*).fastq(.*)$ ]] || [[ "$file" =~ ^(.*).fq(.*) ]]; then  #Solo necesitamos 1 archivo de entrada para el caso de SE
          echo "Start alignment for $file. "  
          hisat2 -x "$prefix_index" \
		 -U "${input_dir}"/"$file" \
		 -S "${file}"_output.sam
	  samtool sort -o "${file}"_output.bam "${file}"_output.sam
	  rm "${file}"_output.sam
  	  echo "Alineado el archivo $file. El resultado es ${file}_output.bam."
      fi
    done
    ;;
esac

print_success "Todos los archivos alineados correctamente."

exit 0

