// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {Socket} from "phoenix"
import topbar from "topbar"
import {LiveSocket} from "phoenix_live_view"

const hooks = {
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
    }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: hooks})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

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
