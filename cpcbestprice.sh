#!/bin/bash

# Horrible nasty hacky script for finding the best price for a CPC stock item.
# Explanation: CPC regularly sends out paper catalogues which have reduced
# products in 'em. However, the prices on the website don't change: to get the
# reduced pricing, you need to use a special product code only available in
# the catalogue. These codes are the same as the full-price product codes, but
# with a two-digit number appended.
# This script takes a standard product code, appends a two-digit number starting
# at 00, and searches CPC's website. If the code leads to a valid product page,
# the price is compared to the normal price - and if it's cheaper, printed
# to standard output. This continues until it has compared all two-digit numbers
# through to 99 - finding you the best possible price.
# Yes, that means 101 searches on CPC's website. Like I said, it's a horribly
# nasty hacky script.

productcode=$(echo $1 | grep '^[A-Za-z][A-Za-z][0-9].*[0-9]')

if [ "$productcode" == "" ]; then
	echo USAGE: $0 PRODUCTCODE
	echo Product codes are two letters, then five or seven numbers.
	echo Any other format will be rejected.
	exit 1
fi

printf "Finding standard price for product code $productcode..."

bestprice=$(wget -q -4 --no-dns-cache -O - "http://cpc.farnell.com/$productcode" | grep taxedvalue -m 1 | cut -d" " -f1 | sed 's/£//')
if [ "$bestprice" == "" ] || [ "$bestprice" == "<span" ]; then
	for i in {1..10}; do
		codenumber=0$i
		bestprice=$(wget -q -4 --no-dns-cache -O - "http://cpc.farnell.com/${productcode:0:7}${codenumber: -2}" | grep taxedvalue -m 1 | cut -d" " -f1 | sed 's/£//')
		if [ "$bestprice" != "" ] && [ "$bestprice" != "<span" ]; then
			break
		fi
	done
fi
if [ "$bestprice" == "" ]; then
	printf " Error.\nProduct $productcode not found.\n"
	exit 1
fi
if [ "$bestprice" == "<span" ]; then
	printf " Error.\nProduct $productcode not found as currently-stocked item.\n"
	exit 1
fi
printf " £$bestprice found.\n"
winningcode=$(echo $productcode at £$bestprice.)
originalpricepence=$(echo $bestprice | sed -e 's/\.//' -e 's/^0*//')

for i in {0..99}; do
	codenumber=0$i
	printf "\rTesting product code ${productcode:0:7}${codenumber: -2}..."
	currentprice=$(wget -q -4 --no-dns-cache -O - "http://cpc.farnell.com/${productcode:0:7}${codenumber: -2}" | grep taxedvalue -m 1 | cut -d" " -f1 | sed 's/£//')
	if [ "$currentprice" != "" ]; then
		currentpricepence=$(echo $currentprice | sed -e 's/\.//' -e 's/^0*//')
		bestpricepence=$(echo $bestprice | sed -e 's/\.//' -e 's/^0*//')
		if [ $currentpricepence -lt $bestpricepence ]; then
			printf " It's cheaper at £$currentprice!\n"
			bestprice=$currentprice
			winningcode=$(echo ${productcode:0:7}${codenumber: -2} at £$bestprice.)
		fi
	fi
done

printf "\rSearch complete!                  \n\n"
echo The cheapest product code found is $winningcode
bestpricepence=$(echo $bestprice | sed -e 's/\.//' -e 's/^0*//')
savingspence=$(($originalpricepence - $bestpricepence))
if [ "${savingspence:-0}" -gt 0 ]; then
	echo Direct link: http://cpc.farnell.com/${winningcode:0:9}
	savingsdigits=$(echo $savingspence | wc -c)
	if [ "$savingsdigits" -le 3 ];
		then
			savingspounds=0
		else
			savingspounds=$(echo $savingspence | sed 's/.\{2\}$//')
	fi		
	savingsremainder=$(echo $savingspence | sed 's/^.*\(.\{2\}\)$/\1/')
	if [ "$savingspounds" -eq 0 ]; then
		if [ "$savingspence" -eq 0 ]; then
			exit 0
		fi
		echo Using this code will save you $savingsremainder\p per unit.
		exit 0
	fi
	echo Using this code will save you £$savingspounds.$savingsremainder per unit.
fi
exit 0
