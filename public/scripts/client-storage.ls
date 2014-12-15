delete-document-state = (key)-> local-storage.remove-item key

get-document-state = (key)-> 
	json-string = local-storage.get-item key
	if !!json-string then JSON.parse json-string else null

save-document-state = (key, document-state)-> local-storage.set-item key, JSON.stringify document-state	

module.exports <<< {delete-document-state, get-document-state, save-document-state}