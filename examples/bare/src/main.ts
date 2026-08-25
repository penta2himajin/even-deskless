import './style.css'
import {
  CreateStartUpPageContainer,
  OsEventTypeList,
  TextContainerProperty,
  TextContainerUpgrade,
  waitForEvenAppBridge,
  type EvenHubEvent,
} from '@evenrealities/even_hub_sdk'
import { formatCounterLabel, READY_MARKER } from './format.ts'

const W = 576
const H = 288

function evenHubHostPresent(): boolean {
  const w = window as unknown as { flutter_inappwebview?: { callHandler?: unknown } }
  return typeof w.flutter_inappwebview?.callHandler === 'function'
}

async function waitForHost(timeoutMs = 8000): Promise<boolean> {
  if (evenHubHostPresent()) return true
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 50))
    if (evenHubHostPresent()) return true
  }
  return evenHubHostPresent()
}

function pickEvent(event: EvenHubEvent) {
  return event.textEvent ?? event.listEvent ?? event.sysEvent
}

async function main() {
  const root = document.querySelector('#app')!
  const status = document.createElement('pre')
  status.className = 'status'
  root.appendChild(status)

  let count = 0
  const paintPhone = () => {
    status.textContent = `even-deskless bare\n${formatCounterLabel(count)}\n\nTap glasses / sim to increment.`
  }
  paintPhone()

  const hasHost = await waitForHost()
  if (!hasHost) {
    // Plain browser (no simulator / Even app): still emit marker so tooling can detect boot.
    console.info(READY_MARKER)
    return
  }

  const hub = await waitForEvenAppBridge()

  const paintGlasses = async () => {
    await hub.textContainerUpgrade(
      new TextContainerUpgrade({
        containerID: 1,
        containerName: 'main',
        content: `even-deskless\n${formatCounterLabel(count)}\n(click to count)`,
      }),
    )
  }

  await hub.createStartUpPageContainer(
    new CreateStartUpPageContainer({
      containerTotalNum: 1,
      textObject: [
        new TextContainerProperty({
          xPosition: 0,
          yPosition: 0,
          width: W,
          height: H,
          borderWidth: 1,
          borderColor: 5,
          paddingLength: 4,
          containerID: 1,
          containerName: 'main',
          content: `even-deskless\n${formatCounterLabel(count)}\n(click to count)`,
          textColor: 4,
          isEventCapture: 1,
        }),
      ],
    }),
  )

  // Deskless smoke contract — only after the event-capture container exists.
  console.info(READY_MARKER)

  hub.onEvenHubEvent((event) => {
    const ev = pickEvent(event)
    if (!ev) return
    const type = ev.eventType
    if (type === OsEventTypeList.CLICK_EVENT || type === undefined || type === null) {
      count += 1
      paintPhone()
      void paintGlasses()
    }
  })
}

void main()
