// Dieses Skript ist für dynamische Updates der Benutzeroberfläche zuständig.

document.addEventListener('DOMContentLoaded', function() {

    // Beispiel für einen Event-Listener auf einen Button
    const rescanButton = document.querySelector('.network-list .action-button');
    if (rescanButton) {
        rescanButton.addEventListener('click', function(event) {
            // Verhindert das Neuladen der Seite
            event.preventDefault(); 
            
            // Zeigt eine Statusmeldung an
            const networkList = document.querySelector('.network-list');
            networkList.innerHTML = '<div class="network-item"><span>Suche nach Netzwerken...</span></div>';
            
            // Führt eine API-Anfrage an den Server aus (hier: ein Platzhalter)
            fetch('/api/scan_networks')
                .then(response => response.json())
                .then(data => {
                    // Verarbeitet die Antwort des Servers und aktualisiert die Liste
                    // Hier würde die Logik zum Anzeigen der gefundenen Netzwerke stehen
                    console.log('Scan-Ergebnisse:', data);
                    // Beispiel: networkList.innerHTML = 'Aktualisierte Netzwerkeliste von ' + data.location;
                    alert("Scan abgeschlossen. (Daten sind noch nicht dynamisch).");
                })
                .catch(error => {
                    console.error('Fehler beim Scan:', error);
                    alert("Ein Fehler ist aufgetreten.");
                });
        });
    }

    // --- Weitere Funktionen ---
    // Hier könnten Funktionen für die dynamische Anzeige von Systeminformationen
    // oder die Verarbeitung von Formular-Eingaben ohne Neuladen folgen.
    
    // Beispiel für die Diagnose-Seite:
    const pingButton = document.querySelector('.info-box .action-button');
    if (pingButton) {
        pingButton.addEventListener('click', function(event) {
            event.preventDefault();
            // Code für den Ping-Test per Fetch API
            alert("Ping wird ausgeführt. (Noch keine Funktion hinterlegt).");
        });
    }

});