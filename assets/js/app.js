import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Get CSRF token for security
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Define Phoenix LiveView hooks
let Hooks = {};

// Editor hook for handling real-time text updates
Hooks.EditorHook = {
    mounted() {
        console.log("EditorHook mounted");
        let editor = this.el;

        // Handle incoming text updates from other users via LiveView push_event
        this.handleEvent("text_updated", ({ text }) => {
            console.log("Updating editor with text:", text);
            editor.value = text;
        });

        this.currentUsername = editor.dataset.username; // store the current username when the hook is mounted
        this.caretTimeouts = new Map(); // store timeouts for each user

        // Track caret positions of other users
        this.handleEvent("caret_positions", ({ positions }) => {
            // Remove any existing carets
            document.querySelectorAll('.user-caret').forEach(el => el.remove());
            
            // Create carets for other users
            positions.forEach(({ username, position, color }) => {
                if (username !== this.currentUsername) {
                    const caret = this.createCaret(username, color);
                    this.positionCaret(caret, position);
                    
                    // Clear existing timeout for this user if any
                    if (this.caretTimeouts.has(username)) {
                        clearTimeout(this.caretTimeouts.get(username));
                    }
                    
                    // Set new timeout to hide caret after 2 seconds of inactivity
                    const timeout = setTimeout(() => {
                        caret.style.opacity = '0';
                        caret.style.transition = 'opacity 0.5s';
                    }, 2000);
                    
                    this.caretTimeouts.set(username, timeout);
                    
                    // Show caret immediately
                    caret.style.opacity = '1';
                    caret.style.transition = 'opacity 0.5s';
                }
            });
        });

        // Create and position caret element
        this.createCaret = (username, color) => {
            const caret = document.createElement('div');
            caret.className = 'user-caret';
            caret.style.backgroundColor = color;
            caret.style.left = '0px';
            caret.setAttribute('data-username', username);
            
            const label = document.createElement('span');
            label.className = 'caret-label';
            label.textContent = username;
            label.style.backgroundColor = color;
            caret.appendChild(label);
            
            editor.parentElement.appendChild(caret);
            return caret;
        };

        // Calculate and set caret position
        this.positionCaret = (caret, position) => {
            const text = editor.value;
            const textBeforeCaret = text.substring(0, position);
            
            // Create temporary element to measure text width
            const temp = document.createElement('div');
            temp.style.font = window.getComputedStyle(editor).font;
            temp.style.whiteSpace = 'pre-wrap';
            temp.style.position = 'absolute';
            temp.style.visibility = 'hidden';
            temp.textContent = textBeforeCaret;
            document.body.appendChild(temp);
            
            // Calculate positions
            const lines = textBeforeCaret.split('\n');
            const lineIndex = lines.length - 1;
            const lastLine = lines[lineIndex];
            temp.textContent = lastLine;
            
            const styles = window.getComputedStyle(editor);
            const lineHeight = parseInt(styles.lineHeight);
            const paddingTop = parseInt(styles.paddingTop);
            const paddingLeft = parseInt(styles.paddingLeft);
            
            // Position the caret
            caret.style.left = `${temp.clientWidth + paddingLeft}px`;
            caret.style.top = `${(lineIndex * lineHeight) + paddingTop}px`;
            
            document.body.removeChild(temp);
        };

        // Track own caret position
        const updateCaretPosition = () => {
            const position = editor.selectionStart;
            this.pushEvent("update_caret", { position: position });
        };

        // Event listener to fix line break problem when user presses Enter
        editor.addEventListener("keydown", (event) => {
            if (event.key === "Enter") {
                const position = editor.selectionStart;
                this.pushEvent("insert_character", { ch_value: "\r", position: position });
                updateCaretPosition();
            }
        });
        // Event listeners to update caret position
        editor.addEventListener("click", updateCaretPosition);
        editor.addEventListener("keyup", updateCaretPosition);
        // Event listener for local user input
        editor.addEventListener("input", (event) => {
            let ch_value = event.data; // inserted char
            let position = editor.selectionStart;

            // Send the appropriate event to LiveView based on the input type
            if (ch_value != null){
                updateCaretPosition() // update the caret position upon input
                this.pushEvent("insert_character", { ch_value: ch_value, position: position - 1 });
            }
        });

        editor.addEventListener("keydown", (event) => {
            if (event.key === "Delete" || event.key === "Backspace") {
                updateCaretPosition() // update the caret position upon input
                let position_start = editor.selectionStart;
                let position_end = editor.selectionEnd;

                this.pushEvent("delete_character", { position_start: position_start , position_end: position_end});
            }
        });
    }
};

// Define live socket and connect to the live endpoint
let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken }, hooks: Hooks 
})

console.log("LiveSocket initialized", liveSocket);

liveSocket.connect()

console.log("LiveSocket connected");
