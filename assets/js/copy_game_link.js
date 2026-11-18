export default {
  mounted() {
    this.copyLink = async () => {
      clearTimeout(this.resetTimer)
      this.el.disabled = true
      const label = this.el.querySelector("[data-copy-label]")

      try {
        await navigator.clipboard.writeText(new URL(this.el.dataset.path, window.location.origin).href)
        label.textContent = "Link copied!"
      } catch {
        label.textContent = "Copy failed. Try again"
      } finally {
        this.el.disabled = false
      }

      this.resetTimer = setTimeout(() => { label.textContent = "Copy game link" }, 3000)
    }
    this.el.addEventListener("click", this.copyLink)
  },

  destroyed() {
    clearTimeout(this.resetTimer)
    this.el.removeEventListener("click", this.copyLink)
  },
}
