import Handlebars from 'handlebars'

const cache = new Map<string, HandlebarsTemplateDelegate>()

export function compileTemplate(source: string): HandlebarsTemplateDelegate {
  const cached = cache.get(source)
  if (cached) return cached

  const compiled = Handlebars.compile(source)
  cache.set(source, compiled)
  return compiled
}

export function clearCache(): void {
  cache.clear()
}
