.PHONY: test test-watch

test:
	shellspec --shell zsh

test-watch:
	nodemon -e zsh,sh,json -w ai.zsh -w "bin/**/*" -w "spec/**/*" -x 'make test || exit 1'
