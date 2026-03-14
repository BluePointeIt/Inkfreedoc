export default class extends HTMLElement {
  connectedCallback () {
    this.currentPageIndex = 0
    this.innerHTML = `
      <div style="position: fixed; right: 20px; bottom: 20px; z-index: 50; display: flex; flex-direction: column; gap: 8px;">
        <button type="button" class="page-nav-btn" id="page-nav-up" title="Page Up" style="width: 44px; height: 44px; border-radius: 50%; background: #291334; color: white; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.3); opacity: 0.85; transition: opacity 0.2s;">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"></polyline></svg>
        </button>
        <div style="text-align: center; background: #291334; color: white; border-radius: 12px; padding: 2px 8px; font-size: 12px; font-weight: 600; min-width: 44px;" id="page-nav-indicator">1 / 1</div>
        <button type="button" class="page-nav-btn" id="page-nav-down" title="Page Down" style="width: 44px; height: 44px; border-radius: 50%; background: #291334; color: white; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.3); opacity: 0.85; transition: opacity 0.2s;">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
        </button>
      </div>
    `

    this.upBtn = this.querySelector('#page-nav-up')
    this.downBtn = this.querySelector('#page-nav-down')
    this.indicator = this.querySelector('#page-nav-indicator')

    this.upBtn.addEventListener('click', this.goUp)
    this.downBtn.addEventListener('click', this.goDown)
    this.upBtn.addEventListener('mouseenter', this.onHover)
    this.upBtn.addEventListener('mouseleave', this.onLeave)
    this.downBtn.addEventListener('mouseenter', this.onHover)
    this.downBtn.addEventListener('mouseleave', this.onLeave)

    window.addEventListener('scroll', this.onScroll)

    this.updatePages()
    this.updateIndicator()
  }

  disconnectedCallback () {
    window.removeEventListener('scroll', this.onScroll)
  }

  onHover = (e) => { e.target.closest('button').style.opacity = '1' }
  onLeave = (e) => { e.target.closest('button').style.opacity = '0.85' }

  getPages () {
    return Array.from(document.querySelectorAll('page-container'))
  }

  updatePages () {
    this.pages = this.getPages()
    if (this.indicator) {
      this.indicator.textContent = this.pages.length > 0
        ? `${this.currentPageIndex + 1} / ${this.pages.length}`
        : '0 / 0'
    }
  }

  getCurrentPageFromScroll () {
    const pages = this.getPages()
    if (pages.length === 0) return 0

    const viewportMiddle = window.innerHeight / 3

    for (let i = pages.length - 1; i >= 0; i--) {
      const rect = pages[i].getBoundingClientRect()
      if (rect.top <= viewportMiddle) {
        return i
      }
    }

    return 0
  }

  onScroll = () => {
    const newIndex = this.getCurrentPageFromScroll()
    if (newIndex !== this.currentPageIndex) {
      this.currentPageIndex = newIndex
      this.pages = this.getPages()
      this.updateIndicator()
    }
  }

  updateIndicator () {
    const pages = this.getPages()
    if (this.indicator && pages.length > 0) {
      this.indicator.textContent = `${this.currentPageIndex + 1} / ${pages.length}`
    }
  }

  goUp = () => {
    this.pages = this.getPages()
    if (this.pages.length === 0) return

    if (this.currentPageIndex > 0) {
      this.currentPageIndex--
    }

    this.pages[this.currentPageIndex].scrollIntoView({ behavior: 'smooth', block: 'start' })
    this.updateIndicator()
  }

  goDown = () => {
    this.pages = this.getPages()
    if (this.pages.length === 0) return

    if (this.currentPageIndex < this.pages.length - 1) {
      this.currentPageIndex++
    }

    this.pages[this.currentPageIndex].scrollIntoView({ behavior: 'smooth', block: 'start' })
    this.updateIndicator()
  }
}
