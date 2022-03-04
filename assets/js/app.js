// Import the CSS such that esbuild processes it.
//
//
// esbuild will gather all CSS files referenced from the given file and
// bundle it into a sibling CSS output file next to the JavaScript output file
// for the JavaScript entry point. So if esbuild generates app.js it would
// also generate app.css containing all CSS files referenced by app.js.
//
// See https://esbuild.github.io/content-types/#css for more.
import "../css/app.scss"

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Can I avoid this hardcoded path?
import "../node_modules/xterm/css/xterm.css"
import { Terminal } from "xterm"

const TileAnimation = {
    rememberTilePositions: () => {
        let tiles = Array.from(document.querySelectorAll("[data-tile-id]"));
        return tiles.reduce((map, tile) => {
            map[tile.dataset.tileId] = {tile: tile, pos: tile.getBoundingClientRect()};
            return map;
        }, {});
    },

    restoreTilePositions: (previousPositions) => {
        let currentPositions = TileAnimation.rememberTilePositions();
        for (var tileId in currentPositions) {
            let currPos = currentPositions[tileId].pos;

            let prevPos;
            if (tileId in previousPositions) {
                prevPos = previousPositions[tileId].pos;
            } else {
                // Newly added tiles seem to show up at the left window border
                prevPos = {x: 0, y: 100, width: 1, height: 1};
            }

            if (prevPos == currPos) {
                continue;
            }

            let dx = prevPos.x - currPos.x;
            let dy = prevPos.y - currPos.y;
            let sx = prevPos.width / currPos.width;
            let sy = prevPos.height / currPos.height;

            currentPositions[tileId].tile.animate([{
              transformOrigin: 'top left',
              transform: `
                translate(${dx}px, ${dy}px)
                scale(${sx}, ${sy})
              `
            }, {
              transformOrigin: 'top left',
              transform: 'none'
            }], {
              duration: 300,
              easing: 'ease-in-out',
              fill: 'backwards'
            });
        }
    }
}

const hooks = {
    TileContainer: {
        beforeUpdate() { this.positions = TileAnimation.rememberTilePositions(); },
        updated() { TileAnimation.restoreTilePositions(this.positions); }
    },

    SetHook: {

    pushTileMovedEvent(tileElem, dstSetElem) {
        let message = {
            tileId: tileElem.dataset.tileId,
            srcSet: tileElem.parentElement.dataset.setIndex,
            destSet: dstSetElem.dataset.setIndex,
        };
        this.pushEvent('tile-moved', message);
    },

    mounted() {
        let hook = this;

        this.el.addEventListener("dragover", function(ev) {
            ev.target.classList.add("dragover");
            ev.preventDefault();
        });

        this.el.addEventListener("dragleave", function(ev) {
            ev.target.classList.remove("dragover");
        });

        this.el.addEventListener("drop", function(ev) {
            let tile = document.getElementById(ev.dataTransfer.getData("application/x-tile-id"));
            tile.classList.remove("dragged");
            hook.pushTileMovedEvent(tile, ev.target);
        });

        this.el.addEventListener("click", function(ev) {
            let tile = document.querySelector(".tile.selected");
            if (tile === null) {
                return;
            }
            tile.classList.remove("selected");
            hook.pushTileMovedEvent(tile, ev.target);
        });
    }
    },

    TileHook: {

        mounted() {
            this.el.addEventListener("dragstart", function(ev) {
                ev.target.classList.remove("selected");
                ev.target.classList.add("dragged");
                ev.dataTransfer.setData("application/x-tile-id", ev.target.id);
            });

            this.el.addEventListener("click", function(ev) {
                let selectedTile = document.querySelector(".tile.selected");
                if (selectedTile === null) {
                    ev.target.classList.add("selected");
                    ev.stopPropagation();
                } else if (selectedTile === ev.target) {
                    selectedTile.classList.remove("selected");
                    ev.stopPropagation();
                    return;
                }
            });
        }
    },

    Terminal: {
        mounted() {
            let term = new Terminal();
            term.open(this.el);
            term.onKey(key => {
                this.pushEvent("key", key);
            });

            window.addEventListener("phx:print", e => {
                term.write(e.detail.data);
            })
        }
    }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: hooks})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

document.addEventListener("dragend", function(ev) {
    if (ev.target.classList.contains("tile")) {
        ev.target.classList.remove("dragged");
    }
});
