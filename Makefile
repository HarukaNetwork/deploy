check:
	while read -r script; do shellcheck --exclude=SC2045 $$script; done < files

.PHONY: check
