// Paste into DevTools on the ORIGINAL game page. Read-only; no credentials exported.
// Includes the account database AND Godot filesystem databases used by older saves.
(async () => {
  const databases = await indexedDB.databases();
  const output = {format: 1, origin: location.origin, databases: []};
  for (const info of databases) {
    if (!info.name || !(info.name === 'tece-island-progress-v4' || /userfs|godot/i.test(info.name))) continue;
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(info.name);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const entry = {name: info.name, stores: []};
    for (const name of db.objectStoreNames) {
      const values = await new Promise((resolve, reject) => {
        const transaction = db.transaction(name, 'readonly'), rows = [];
        const request = transaction.objectStore(name).openCursor();
        request.onsuccess = () => {const cursor = request.result; if (cursor) {rows.push({key: cursor.key, value: cursor.value}); cursor.continue();}};
        transaction.oncomplete = () => resolve(rows);
        transaction.onabort = () => reject(transaction.error);
      });
      entry.stores.push({name, entries: values});
    }
    db.close(); output.databases.push(entry);
  }
  const blob = new Blob([JSON.stringify(output, (_key, value) => value instanceof Uint8Array ? {type: 'bytes', bytes: Array.from(value)} : value, 2)], {type: 'application/json'});
  const link = document.createElement('a'); link.href = URL.createObjectURL(blob);
  link.download = 'tece-island-diagnostico.json'; link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  console.info('Cópia exportada. Nenhum armazenamento foi apagado.', {databases: output.databases.length, bytes: blob.size});
})();
