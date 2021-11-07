#!/bin/sh

# Receives files as arguments, scans them for lines like
# #> FETCH e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19
# #>  FROM http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
# downloads to ./downloads if file's not present there yet, verifies hash,
# copies file over to $DESTDIR.

set -ue

: ${DESTDIR:=stage/downloads}  # final location of putting the file
: ${ONLY:=all}  # allow to limit to just a single file
mkdir -p downloads   # first cached there, so that stage can be cleaned freely

fetch() {
	hash=$1; url=$2; filename=${3:-$(basename "$url")}
	if [[ -e "downloads/$filename" ]]; then
		pushd downloads >/dev/null
			echo "$hash $filename" | sha256sum -c
		popd >/dev/null
	else
		mkdir -p downloads/.tmp$$
		pushd downloads/.tmp$$ >/dev/null
			wget -nv --show-progress "$url" -O "$filename"
			echo "$hash $filename" | sha256sum -c --quiet
		popd >/dev/null
		mv "downloads/.tmp$$/$filename" downloads/
		rm -d downloads/.tmp$$
		if [[ "${DESTDIR:-}" != downloads ]]; then
			mkdir -p "$DESTDIR"
			cp --reflink=auto "downloads/$filename" \
				"$DESTDIR/$filename"
		fi
	fi
}

process_commands_in() {
	hash=''; url=''; filename=''
	while read -r line; do
		REGEX_MAGIC='^#> '
		REGEX_FETCH='^#> FETCH'
		REGEX_FROM='^#>  FROM'
		REGEX_AS='^#>    AS'
		if [[ "$line" =~ $REGEX_MAGIC ]]; then
			if [[ "$line" =~ $REGEX_FETCH ]]; then
				hash="${line##"#> FETCH"}"
			elif [[ "$line" =~ $REGEX_FROM ]]; then
				url="${line##'#>  FROM '}"
			elif [[ "$line" =~ $REGEX_AS ]]; then
				filename="${line##'#>    AS '}"
			else
				echo "### $0: malformed line '$line' in '$1'"
				exit 2
			fi
		else
			if [[ -n "$hash" && -n "$url" ]]; then
				filename=${filename:-$(basename $url)}
				if [[ "$ONLY" == all || \
						"$ONLY" == "$filename" ]]; then
					fetch "$hash" "$url" "$filename"
				fi
			fi
			hash=''; url=''; filename=''
		fi
	done < $1
}

if [[ $# == 0 ]]; then
	files="1/seed.host-executed.sh 2/[0-9]*.sh"
else
	files="$@"
fi

for f in $files; do
	process_commands_in $f
done
