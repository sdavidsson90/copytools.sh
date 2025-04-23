# ==========================================
# Identify clipboard tool
if command -v pbcopy &>/dev/null; then # MacOS
  copy() {
    pbcopy
  }
  paste() {
    pbpaste
  }
elif command -v xsel &>/dev/null; then # Linux (X11)
  copy() {
    xsel -ib
  }
  paste() {
    xsel -ob
  }
elif command -v wl-copy &>/dev/null; then # Linux (Wayland)
  copy() {
    wl-copy
  }
  paste() {
    wl-paste
  }
fi

# ==========================================
# Copy working directory
cpwd() {

  # Clear clipboard
  printf "%s" "" | copy

  echo "$PWD/" | copy
  echo -e "\e[1mCopied working directory:\e[0m"
  paste
}

# ==========================================
# Copy file paths
cpfp() {

  # If no arguments are given; stop and return error
  [ -z "$1" ] && echo "No target files provided!" && return 1

  # Gather file paths and invalid input
  j=1
  for i in "$@"; do
    if [ -e "$i" ]; then
      file_path[$j]=$(realpath "$i")
      ((j++))
    else
      invalid+="$i"
      invalid+=' '
    fi
  done

  # Clear clipboard
  printf "%s" "" | copy

  # Do the copy action and print copied filepaths
  if [ -n "${file_path[1]}" ]; then
    echo -n "${file_path[@]}" | copy &&
      echo -e "\e[1mCopied filepaths:\e[0m"
    for i in "${file_path[@]}"; do
      echo "$i"
    done

    # If both valid and invalid input are to be printed; print newline before invalid
    [ -n "$invalid" ] && echo ""
  fi

  # Print invalid inputs
  if [ -n "$invalid" ]; then
    echo -e "\e[1mInvalid input:\e[0m"
    for i in "${invalid[@]}"; do
      echo "$invalid"
    done
  fi

  unset j file_path invalid
}

# ==========================================
# Copy file contents
cpfc() {

  # If no arguments are given; stop and return error
  [ -z "$1" ] && echo "No target files provided!" && return 1

  # Gather file paths and invalid input
  j=1
  for i in "$@"; do
    if [ -e "$i" ]; then
      file_path[$j]=$(realpath "$i")
      file_contents+=$(cat "$i")
      ((j++))
    else
      invalid+="$i"
      invalid+=$'\n'
    fi
  done

  # Clear clipboard
  printf "%s" "" | copy

  # Do the copy action and print paths of copied files
  if [ -n "${file_path[1]}" ]; then
    printf "%s" "$file_contents" | copy
    echo -e "\e[1mCopied file contents of:\e[0m"
    for i in "${file_path[@]}"; do
      echo "$i"
    done

    # If invalid input was also given; print newline for sepearation
    [ -n "$invalid" ] && echo ''
  fi

  # Print invalid inputs
  if [ -n "$invalid" ]; then
    echo -e "\e[1mInvalid input:\e[0m"
    printf "%s" "$invalid"
  fi

  unset j file_path file_contents invalid
}

# ==========================================
# Paste clipboard content to stdout
alias p=paste

# ==========================================
# Paste file(s) to current directory
pf() {

  # Create array from clipboard items
  items=($(paste))

  # Gather valid filepaths from clipboard
  # Clipboard items may contain file paths with spaces
  # These need to be reassembled based on a set of rules
  j=1
  for i in "${items[@]}"; do
    if [[ -e "$i" ]]; then
      if [[ "$i" = '/'* ]]; then
        valid[$j]+="$i"
        ((j++))
        if [[ -n $invalid ]]; then
          invalid+=' '
        fi
        invalid+="$possibly"
        possibly=''
      fi
    else
      if [[ "$i" = '/'* ]]; then
        if [[ -n $possibly ]]; then
          if [[ -n $invalid ]]; then
            invalid+=' '
          fi
          invalid+="$possibly"
        fi
        possibly=$i
      else
        if [[ -n $possibly ]]; then
          possibly+=' '
        else
          if [[ -n $invalid ]]; then
            invalid+=' '
          fi
          invalid+=$i
          continue
        fi
        possibly+="$i"
      fi
      if [[ -e $possibly ]]; then
        valid[$j]+="$possibly"
        ((j++))
        possibly=''
      fi
    fi
  done

  # Print header if clipboard contains any valid filepath
  if [[ -n "${valid[1]}" ]]; then
    echo -e "\e[1mPasting files:\e[0m"
  else
    echo "Could not find any valid filepaths in clipboard!"
    return 1
  fi

  for i in "${valid[@]}"; do
    echo -n "$i"

    # Check if filename exists in this location.
    # If so; ask if the existing file should be replaced.
    if [[ -e $(basename "$i") ]]; then

      echo -e "\n  A file with this name already exists in this location!"
      echo -n "  Do you wish to overwrite? [Y/n]: "

      response=$(bash -c "read -n 1 response; echo -n \$response")

      if [ -z "$response" ]; then
        response='Y'
        # Delete previous line (empty because user hit enter)
        echo -en "\033[1A\033[2K"
        echo -n "  Do you wish to overwrite? [Y/n]: y"
      fi

      while [[ ! "$response" =~ ^[YyNn]$ ]]; do
        echo -en "\n  Invalid response! Try again! [Y/n]: "
        response=$(bash -c "read -n 1 response; echo -n \$response")
        # If input is 'enter' - accept as 'Y':
        if [ -z "$response" ]; then
          response='Y'
          # Delete previous line (empty because user hit enter)
          echo -en "\033[1A\033[2K"
          echo -en "  Invalid response! Try again! [Y/n]: y"
        fi
      done

      case "$response" in
      [Yy])
        cp -r "$i" . 2>/dev/null && echo " [✓]" || echo " [x]"
        echo ""
        ;;
      [Nn])
        echo " [x]"
        echo ""
        ;;
      esac

      # Does the print end in a double newline?
      remove_newline=true

    elif [[ ! -e $(basename "$i") ]]; then
      cp -r "$i" . 2>/dev/null && echo " [✓]" || echo " [x]"

      # Does the print end in a double newline?
      remove_newline=false
    fi

    unset response

  done

  if [ -n "$invalid" ]; then
    echo ""
    echo -e "\e[1mInvalid filepaths:\e[0m"
    for i in ${invalid[@]}; do
      echo "$invalid"
    done
    remove_newline=true
  fi

  # Remove superfluous newline
  if [[ $remove_newline = true ]]; then
    echo -en "\033[1A\033[2K"
  fi

  unset items j valid possibly invalid
}

# ==========================================
# Move file(s) to current directory
mvf() {

  # Create array from clipboard items
  items=($(paste))

  # Gather valid filepaths from clipboard
  # Clipboard items may contain file paths with spaces
  # These need to be reassembled based on a set of rules
  j=1
  for i in "${items[@]}"; do
    if [[ -e "$i" ]]; then
      if [[ "$i" = '/'* ]]; then
        valid[$j]+="$i"
        ((j++))
        if [[ -n $invalid ]]; then
          invalid+=' '
        fi
        invalid+="$possibly"
        possibly=''
      fi
    else
      if [[ "$i" = '/'* ]]; then
        if [[ -n $possibly ]]; then
          if [[ -n $invalid ]]; then
            invalid+=' '
          fi
          invalid+="$possibly"
        fi
        possibly=$i
      else
        if [[ -n $possibly ]]; then
          possibly+=' '
        else
          if [[ -n $invalid ]]; then
            invalid+=' '
          fi
          invalid+=$i
          continue
        fi
        possibly+="$i"
      fi
      if [[ -e $possibly ]]; then
        valid[$j]+="$possibly"
        ((j++))
        possibly=''
      fi
    fi
  done

  # Print header if clipboard contains any valid filepath
  if [[ -n "${valid[1]}" ]]; then
    echo -e "\e[1mMoving files:\e[0m"
  else
    echo "Could not find any valid filepaths in clipboard!"
    return 1
  fi

  for i in "${valid[@]}"; do
    echo -n "$i"

    # Check if filename exists in this location.
    # If so; ask if the existing file should be replaced.
    if [[ -e $(basename "$i") ]]; then

      echo -e "\n  A file with this name already exists in this location!"
      echo -n "  Do you wish to overwrite? [Y/n]: "

      response=$(bash -c "read -n 1 response; echo -n \$response")

      if [ -z "$response" ]; then
        response='Y'
        # Delete previous line (empty because user hit enter)
        echo -en "\033[1A\033[2K"
        echo -n "  Do you wish to overwrite? [Y/n]: y"
      fi

      while [[ ! "$response" =~ ^[YyNn]$ ]]; do
        echo -en "\n  Invalid response! Try again! [Y/n]: "
        response=$(bash -c "read -n 1 response; echo -n \$response")
        # If input is 'enter' - accept as 'Y':
        if [ -z "$response" ]; then
          response='Y'
          # Delete previous line (empty because user hit enter)
          echo -en "\033[1A\033[2K"
          echo -en "  Invalid response! Try again! [Y/n]: y"
        fi
      done

      case "$response" in
      [Yy])
        cp -r "$i" . 2>/dev/null && rm -rf "$i" && echo " [✓]" || echo " [x]"
        echo ""
        ;;
      [Nn])
        echo " [x]"
        echo ""
        ;;
      esac

      # Does the print end in a double newline?
      remove_newline=true

    elif [[ ! -e $(basename "$i") ]]; then
      cp -r "$i" . 2>/dev/null && rm -rf "$i" && echo " [✓]" || echo " [x]"

      # Does the print end in a double newline?
      remove_newline=false
    fi

    unset response

  done

  if [ -n "$invalid" ]; then
    echo ""
    echo -e "\e[1mInvalid filepaths:\e[0m"
    for i in ${invalid[@]}; do
      echo "$invalid"
    done
    remove_newline=true
  fi

  # Remove superfluous newline
  if [[ $remove_newline = true ]]; then
    echo -en "\033[1A\033[2K"
  fi

  unset items j valid possibly invalid
}
