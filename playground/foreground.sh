clear
echo "Pulling the emacs-camp image..."
docker pull -q ghcr.io/ajchemist/emacs-camp-demo:latest >/dev/null
echo 'Run `emacs` (C-x C-c quits). Files under ~ vanish when the session ends.'
docker run --rm -it ghcr.io/ajchemist/emacs-camp-demo:latest bash
