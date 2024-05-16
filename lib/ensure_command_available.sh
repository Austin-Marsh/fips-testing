ensure_command_available() {
    # Ensure Homebrew is installed
    if ! type brew > /dev/null; then
        echo "Homebrew is not installed."
        echo "Please install Homebrew by running the following command:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "Exiting..."
        exit 1
    fi

    COMMAND=$1
    # Check if the command is installed
    if ! command -v $COMMAND &> /dev/null; then
        # Search for the package that provides the command
        echo "Searching for the package that provides $COMMAND..."
        PACKAGE=$(brew search --formula $COMMAND 2> /dev/null | grep -E "^$COMMAND$" || brew search --formula $COMMAND 2> /dev/null | grep -E "$COMMAND")

        if [ -z "$PACKAGE" ]; then
            echo "Could not find a Homebrew package that provides $COMMAND. Exiting..."
            exit 1
        fi

        echo "Found package $PACKAGE for command $COMMAND."

        while true; do
            echo "$COMMAND is not installed."
            read -p "Would you like to install $PACKAGE using Homebrew? (yes/no/quit): " choice

            case "$choice" in
                [yY]|[yY][eE][sS])
                    # Install the package using Homebrew
                    echo "Installing $PACKAGE using Homebrew..."
                    brew install $PACKAGE
                    break
                    ;;
                [nN]|[nN][oO])
                    echo "Skipping $PACKAGE installation. Exiting..."
                    exit 1
                    ;;
                [qQ]|[qQ][uU][iI][tT])
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'yes', 'no', or 'quit'."
                    ;;
            esac
        done
    fi

    # Ensure the command is in your $PATH

    # Detect the default shell
    default_shell=$(basename "$SHELL")

    # Find the command path using brew
    command_path=$(brew --prefix $COMMAND)/bin

    # Determine the appropriate shell configuration file
    case "$default_shell" in
        bash)
            shell_rc_file="$HOME/.bashrc"
            ;;
        zsh)
            shell_rc_file="$HOME/.zshrc"
            ;;
        fish)
            shell_rc_file="$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "Unsupported shell: $default_shell"
            exit 1
            ;;
    esac

    # Add the command path to the shell configuration file
    if grep -q "$command_path" "$shell_rc_file"; then
        echo "$COMMAND path is already in $shell_rc_file"
    else
        if [[ "$default_shell" == "fish" ]]; then
            echo "set -x PATH $command_path \$PATH" >> "$shell_rc_file"
        else
            echo "export PATH=\"$command_path:\$PATH\"" >> "$shell_rc_file"
        fi
        echo "$COMMAND path added to $shell_rc_file."
    fi

    echo "Sourcing your shell's rc file: $shell_rc_file"
    source $shell_rc_file
}