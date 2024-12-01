import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {};
let editor = document.querySelector("#editor");

// Define live socket and connect to the live endpoint
let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken, hooks: Hooks }
})

liveSocket.connect()

Hooks.EditorHook = {
    mounted() {
        this.el.addEventListener("keyup", (event) => {
            let ch_value = event.data; // inserted char
            let cursor_position = editor.selectionStart; // cursor position before input
            if (ch_value != null){
                this.pushEvent("insert_character", { ch_value: ch_value, position: cursor_position-1 });
            } else
            {
                this.pushEvent("delete_character", { position: cursor_position });
            }
        });
    }
};
