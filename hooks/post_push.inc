## get the repo and tag strings
#
image_repo=${IMAGE_NAME%:*}
image_tag=${IMAGE_NAME#*:}

## generate and apply extra tags
#
tags=()

case "${image_tag}" in
	latest)
		image_tag="${latest}"
		;;
	"${latest}"|"v${latest}")
		tags+=( 'latest' )
		;;
esac

## push the tags
#
push_tags()	{
	for tag in ${tags[@]}; do
		echo '---'
		echo "Adding tag: ${image_repo}:${tag}"
		docker tag $IMAGE_NAME ${image_repo}:${tag}
		docker push ${image_repo}:${tag} | grep digest
	done
	echo '---'
}
