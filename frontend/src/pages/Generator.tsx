import { useEffect, useRef, useState } from 'react'
import { useForm } from '@tanstack/react-form'
import { useMutation } from '@tanstack/react-query'
import { Loader2, CheckCircle2 } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import confetti from 'canvas-confetti'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { urlSchema, URL_MAX_LENGTH } from '@/schemas/url'
import { createQr } from '@/api/qr'
import { create as createRenderer, type QRRenderer } from '@/qr/renderer'
import type { ApiError } from '@/api/client'
import { useMotionPreference } from '@/lib/motionPreference'
import { getToastOptions } from '@/lib/toastOptions'

const BASE_URL = import.meta.env.VITE_BASE_URL ?? window.location.origin

function validateUrl(value: string): string | undefined {
  if (!value) return '請輸入網址'
  const result = urlSchema.safeParse(value)
  return result.success ? undefined : result.error.issues[0].message
}

export function Generator() {
  const qrContainerRef = useRef<HTMLDivElement>(null)
  const rendererRef = useRef<QRRenderer | null>(null)
  const [shortUrl, setShortUrl] = useState<string | null>(null)
  const [jitterKey, setJitterKey] = useState(0)
  const prefersReducedMotion = useMotionPreference()

  useEffect(() => {
    return () => {
      rendererRef.current?.destroy()
    }
  }, [])

  const mutation = useMutation({
    mutationFn: createQr,
    onSuccess(data) {
      const qrUrl = `${BASE_URL}/r/${data.token}`
      setShortUrl(qrUrl)
      setJitterKey((k) => k + 1)

      rendererRef.current?.destroy()
      rendererRef.current = null

      const renderer = createRenderer({
        width: 256,
        height: 256,
        data: qrUrl,
        dotsOptions: { color: '#000000', type: 'square' },
        backgroundOptions: { color: '#ffffff' },
        cornersSquareOptions: { type: 'square' },
        cornersDotOptions: { type: 'square' },
      })
      rendererRef.current = renderer

      if (qrContainerRef.current) {
        renderer.attachTo(qrContainerRef.current)
      }

      toast.success('QR 碼已產生！', getToastOptions('success'))

      if (!prefersReducedMotion) {
        confetti({ particleCount: 100, spread: 70, origin: { y: 0.6 } })
      }
    },
    onError(err) {
      const apiErr = err as unknown as ApiError
      if (apiErr.isNetwork || apiErr.status !== 422) {
        toast.error('網路錯誤，請稍後再試。', getToastOptions('error'))
      }
    },
  })

  const form = useForm({
    defaultValues: { url: '' },
    onSubmit({ value }) {
      mutation.mutate({ url: value.url })
    },
  })

  const apiError = mutation.error as ApiError | null

  return (
    <div className="flex flex-col gap-6 max-w-lg">
      <div>
        <h1 className="text-2xl font-bold">QR 碼產生器</h1>
        <p className="text-muted-foreground mt-1">
          輸入目標網址，即可產生專屬的短網址 QR 碼。
        </p>
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault()
          e.stopPropagation()
          form.handleSubmit()
        }}
        className="flex flex-col gap-4"
      >
        <form.Field
          name="url"
          validators={{
            onChange: ({ value }) => validateUrl(value),
            onBlur: ({ value }) => validateUrl(value),
            onSubmit: ({ value }) => validateUrl(value),
          }}
        >
          {(field) => {
            const inlineError =
              field.state.meta.isTouched && field.state.meta.errors.length > 0
                ? String(field.state.meta.errors[0])
                : mutation.isError && apiError?.status === 422
                ? apiError.detail
                : null

            function handlePaste(e: React.ClipboardEvent<HTMLInputElement>) {
              const pasted = e.clipboardData.getData('text')
              const combined = field.state.value + pasted
              if (combined.length > URL_MAX_LENGTH) {
                e.preventDefault()
                const allowed = URL_MAX_LENGTH - field.state.value.length
                if (allowed > 0) {
                  field.handleChange(field.state.value + pasted.slice(0, allowed))
                }
              }
            }

            return (
              <div className="flex flex-col gap-1">
                <div className="flex items-center gap-2">
                  <label htmlFor="url-input" className="text-sm font-medium">
                    目標網址
                  </label>
                  <AnimatePresence>
                    {shortUrl && (
                      <motion.span
                        initial={{ opacity: 0, scale: 0.8 }}
                        animate={{ opacity: 1, scale: 1 }}
                        exit={{ opacity: 0 }}
                        className="flex items-center gap-1 text-xs text-green-600 font-medium"
                      >
                        <CheckCircle2 className="h-3 w-3" />
                        已產生
                      </motion.span>
                    )}
                  </AnimatePresence>
                </div>
                <input
                  id="url-input"
                  type="text"
                  className={[
                    'rounded-md border px-3 py-2 text-sm outline-none',
                    'focus:ring-2 focus:ring-primary/50',
                    inlineError
                      ? 'border-destructive focus:ring-destructive/50'
                      : 'border-input',
                  ].join(' ')}
                  placeholder="https://example.com/your-long-url"
                  value={field.state.value}
                  maxLength={URL_MAX_LENGTH}
                  onPaste={handlePaste}
                  onChange={(e) => field.handleChange(e.target.value)}
                  onBlur={field.handleBlur}
                  disabled={mutation.isPending}
                />
                <div className="flex justify-between text-xs">
                  <span className={inlineError ? 'text-destructive' : 'text-transparent select-none'}>
                    {inlineError ?? '　'}
                  </span>
                  <span
                    className={
                      field.state.value.length >= URL_MAX_LENGTH
                        ? 'text-destructive'
                        : 'text-muted-foreground'
                    }
                  >
                    {field.state.value.length} / {URL_MAX_LENGTH}
                  </span>
                </div>
              </div>
            )
          }}
        </form.Field>

        <Button
          type="submit"
          disabled={mutation.isPending}
          className={mutation.isPending ? 'grayscale' : ''}
        >
          {mutation.isPending ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              產生中…
            </>
          ) : (
            '產生 QR 碼'
          )}
        </Button>
      </form>

      <div
        className={[
          'flex items-center justify-center rounded-lg border bg-white',
          'min-h-[280px] transition-all',
          shortUrl ? 'border-border' : 'border-dashed border-muted-foreground/30',
        ].join(' ')}
      >
        {shortUrl ? (
          <motion.div
            key={jitterKey}
            animate={
              prefersReducedMotion
                ? { opacity: 1 }
                : { x: [-3, 3, -3, 3, 0], opacity: 1 }
            }
            initial={{ opacity: prefersReducedMotion ? 0.5 : 1 }}
            transition={{ duration: 0.35 }}
          >
            <div ref={qrContainerRef} />
          </motion.div>
        ) : (
          <p className="text-sm text-muted-foreground">QR 碼預覽將顯示在這裡</p>
        )}
      </div>
    </div>
  )
}
