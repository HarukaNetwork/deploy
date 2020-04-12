check:
	while read -r script; do shellcheck --exclude=SC2045,SC2129 $$script; done < files

.PHONY: check
