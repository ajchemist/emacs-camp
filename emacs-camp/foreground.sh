clear
echo "Pulling the emacs-camp image..."
docker pull ghcr.io/ajchemist/emacs-camp:latest
echo 'Run `emacs` (C-x C-c quits). Files under ~ vanish when the session ends.'
docker run --rm -it ghcr.io/ajchemist/emacs-camp:latest bash
