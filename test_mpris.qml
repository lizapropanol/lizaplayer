import Quickshell
import Quickshell.Services.Mpris
import QtQml

ShellRoot {
    Component.onCompleted: {
        console.log("Players count: " + Mpris.players.values.length);
        for (let i = 0; i < Mpris.players.values.length; i++) {
            console.log("Player " + i + ": " + Mpris.players.values[i].identity + " busName: " + Mpris.players.values[i].busName);
        }
        Quickshell.exit(0);
    }
}