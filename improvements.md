# improvements

## bugs
 - every tab flash ~500ms, maybe reloading the screen? It is on the map, species, gallery, dataset tab

## small improvements
 - default radius down to 2.5km

 # more taxon filters
 - remove the all globe icon and instead allow to deselect an icon: None selected = all
 - add a small auto complete form for entering a taxonomic name next to the kingdom icon filters which is then used as the taxonKey parameter value instead of the kingdoms to filter all searches. The kingdom values 1, 5 & 6 can also be used with taxonKey - no need to use different parameters to filter for a taxon.
   Use the species suggest API to lookup taxon keys. If a kingdom filter was selected include it into the suggest via higherTaxonKey. Make sure there is a way to deselect or reenter selected taxon filters.

