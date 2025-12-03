#!/bin/bash

##############################################
#           COLOR DEFINITIONS                #
##############################################
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

##############################################
#               ASCII BANNER                 #
##############################################
clear
echo -e "${CYAN}"
echo "==============================================="
echo "     ██████╗  █████╗ ████████╗ ██████╗██╗  ██╗"
echo "     ██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██║ ██╔╝"
echo "     ██████╔╝███████║   ██║   ██║     █████╔╝ "
echo "     ██╔══██╗██╔══██║   ██║   ██║     ██╔═██╗ "
echo "     ██████╔╝██║  ██║   ██║   ╚██████╗██║  ██╗"
echo "     ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝"
echo "==============================================="
echo -e "${RESET}"

echo -e "${BLUE}🎬 Welcome to the Batch Video Converter!${RESET}"
echo

##############################################
#                 SPINNER                    #
##############################################
spinner() {
    local pid=$!
    local spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    local char

    while kill -0 "$pid" 2>/dev/null; do
        for char in $(echo "$spin" | grep -o .); do
            echo -ne " ${YELLOW}Processing...${RESET} $char\r"
            sleep 0.15
        done
    done
    echo -ne "\r${GREEN}✔ Done!                     ${RESET}\n"
}

##############################################
#      SIMPLE DIRECTORY BROWSER (TUI)        #
##############################################
select_directory() {
    local current_dir="$1"
    while true; do
        clear
        echo -e "${CYAN}Current directory:${RESET} $current_dir"
        echo
        echo -e "${YELLOW}Subdirectories:${RESET}"

        # Build list of subdirectories
        mapfile -t dirs < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" | sort)
        local idx=1
        for d in "${dirs[@]}"; do
            basename_dir=$(basename "$d")
            echo " $idx) $basename_dir"
            ((idx++))
        done

        echo
        echo "Options:"
        echo "  u) Go up one level"
        echo "  c) Choose current directory"
        echo "  q) Cancel"
        echo
        read -rp "Select a directory (number) or option: " choice

        case "$choice" in
            [0-9]*)
                if (( choice >= 1 && choice <= ${#dirs[@]} )); then
                    current_dir="${dirs[choice-1]}"
                else
                    echo -e "${RED}Invalid selection.${RESET}"
                    sleep 1
                fi
                ;;
            u)
                # Go up one level, but don't go above /
                if [[ "$current_dir" != "/" ]]; then
                    current_dir=$(dirname "$current_dir")
                fi
                ;;
            c)
                echo "$current_dir"
                return 0
                ;;
            q)
                return 1
                ;;
            *)
                echo -e "${RED}Invalid option.${RESET}"
                sleep 1
                ;;
        esac
    done
}

##############################################
#          FORMAT SELECTION MENU             #
##############################################
echo -e "${CYAN}Choose output formats (comma-separated):${RESET}"
echo -e "${YELLOW} 1) AVI (Xvid)"
echo " 2) MP4 (H.264)"
echo " 3) MKV (H.264)"
echo -e " 4) WEBM (VP9)${RESET}"
echo
read -p "Enter options (e.g., 1,3): " choices

OUTPUT_FORMATS=()
IFS=',' read -ra OPTIONS <<< "$choices"

for c in "${OPTIONS[@]}"; do
    case "$c" in
        1) OUTPUT_FORMATS+=("avi") ;;
        2) OUTPUT_FORMATS+=("mp4") ;;
        3) OUTPUT_FORMATS+=("mkv") ;;
        4) OUTPUT_FORMATS+=("webm") ;;
        *) echo -e "${RED}⚠ Invalid option ignored: $c${RESET}" ;;
    esac
done

if [ ${#OUTPUT_FORMATS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No valid formats selected. Exiting.${RESET}"
    exit 1
fi

echo
echo -e "${GREEN}Selected formats:${RESET} ${OUTPUT_FORMATS[*]}"
echo

##############################################
#       PATH SELECTION (NO EXTRA TOOLS)      #
##############################################
echo -e "${CYAN}Select INPUT directory using the browser.${RESET}"
echo -e "${CYAN}(Starting from current directory: $(pwd))${RESET}"
echo
read -rp "Press Enter to open browser, or type a path manually: " manual_input

if [[ -n "$manual_input" ]]; then
    INPUT_DIR="$manual_input"
else
    if ! INPUT_DIR=$(select_directory "$(pwd)"); then
        echo -e "${RED}❌ Input directory selection cancelled. Exiting.${RESET}"
        exit 1
    fi
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo -e "${RED}❌ Input directory does not exist. Exiting.${RESET}"
    exit 1
fi

echo
echo -e "${CYAN}Select OUTPUT directory using the browser.${RESET}"
echo -e "${CYAN}(Starting from current directory: $(pwd))${RESET}"
echo
read -rp "Press Enter to open browser, or type a path manually: " manual_output

if [[ -n "$manual_output" ]]; then
    OUTPUT_DIR="$manual_output"
else
    if ! OUTPUT_DIR=$(select_directory "$(pwd)"); then
        echo -e "${RED}❌ Output directory selection cancelled. Exiting.${RESET}"
        exit 1
    fi
fi

mkdir -p "$OUTPUT_DIR"

echo
echo -e "${CYAN}Input:${RESET}  $INPUT_DIR"
echo -e "${CYAN}Output:${RESET} $OUTPUT_DIR"
echo

##############################################
#                 PROCESS FILES              #
##############################################
shopt -s nullglob
for file in "$INPUT_DIR"/*.{avi,mp4,mkv,flv,webm,mov}; do

    filename=$(basename "$file")
    base="${filename%.*}"

    echo -e "${BLUE}-----------------------------------------------${RESET}"
    echo -e "${CYAN}🎞 Processing:${RESET} $filename"
    echo -e "${BLUE}-----------------------------------------------${RESET}"

    for fmt in "${OUTPUT_FORMATS[@]}"; do
        echo -e "${YELLOW}🔧 Converting → $fmt ...${RESET}"

        case "$fmt" in
            avi)
                ffmpeg -i "$file" \
                    -vf scale=640:480 \
                    -c:v mpeg4 -vtag xvid -b:v 800k \
                    -c:a libmp3lame -b:a 160k \
                    "$OUTPUT_DIR/${base}_converted.avi" & spinner
                ;;
            mp4)
                ffmpeg -i "$file" \
                    -vf scale=1280:720 \
                    -c:v libx264 -preset faster -crf 24 \
                    -c:a aac -b:a 160k \
                    "$OUTPUT_DIR/${base}_converted.mp4" & spinner
                ;;
            mkv)
                ffmpeg -i "$file" \
                    -vf scale=1280:720 \
                    -c:v libx264 -preset faster -crf 24 \
                    -c:a aac -b:a 160k \
                    "$OUTPUT_DIR/${base}_converted.mkv" & spinner
                ;;
            webm)
                ffmpeg -i "$file" \
                    -vf scale=1280:720 \
                    -c:v libvpx-vp9 -b:v 800k -speed 4 \
                    -c:a libopus -b:a 160k \
                    "$OUTPUT_DIR/${base}_converted.webm" & spinner
                ;;
        esac
    done

    # Subtitle extraction
    echo -e "${CYAN}📝 Extracting subtitles...${RESET}"
    ffmpeg -y -i "$file" \
        -map 0:s:0 \
        "$OUTPUT_DIR/${base}_converted_raw.srt" &>/dev/null

    if [[ -f "$OUTPUT_DIR/${base}_converted_raw.srt" ]]; then
        echo -e "${YELLOW}🧹 Cleaning subtitle tags...${RESET}"
        sed 's/<[^>]*>//g' "$OUTPUT_DIR/${base}_converted_raw.srt" \
            > "$OUTPUT_DIR/${base}_converted.srt"
        rm "$OUTPUT_DIR/${base}_converted_raw.srt"
    else
        echo -e "${RED}⚠ No subtitle stream found.${RESET}"
    fi

    echo -e "${GREEN}✔ Finished:${RESET} $base"
done

echo
echo -e "${GREEN}🎉 All conversions completed!${RESET}"
echo -e "${CYAN}Output saved in:${RESET} $OUTPUT_DIR"