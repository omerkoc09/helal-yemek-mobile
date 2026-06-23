declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  
  const component: DefineComponent<{}, {}, any>
  export default component
}


declare module 'vue-prism-component' {
  import { ComponentOptions } from 'vue'
  const component: ComponentOptions
  export default component
}
declare module 'vue-shepherd';
declare module '@videojs-player/vue';

declare module '*.svg?component' {
  import type { FunctionalComponent, SVGAttributes } from 'vue'
  const src: FunctionalComponent<SVGAttributes>
  export default src
}

declare module '*.svg?skipsvgo' {
  import type { FunctionalComponent, SVGAttributes } from 'vue'
  const src: FunctionalComponent<SVGAttributes>
  export default src
}
