get-document-state = (query-id)-> 
	json-string = local-storage.get-item query-id
	if !!json-string then JSON.parse json-string else null

save-document-state = (key, document-state)-> local-storage.set-item key, JSON.stringify document-state	

module.exports <<< {get-document-state, save-document-state}