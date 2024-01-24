.PHONY: test test-watch

test:
	shellspec --shell zsh

test-watch:
	nodemon -w ai.zsh -w bin/**/* -w spec/**/* -e zsh,sh -x 'make test || exit 1'
