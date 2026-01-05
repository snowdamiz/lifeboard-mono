<script setup lang="ts">
import { RouterView } from 'vue-router'
import Sidebar from './Sidebar.vue'
import TopNav from './TopNav.vue'
import MobileNav from './MobileNav.vue'
</script>

<template>
  <div class="flex h-screen bg-background">
    <Sidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <TopNav />
      <main class="flex-1 overflow-auto scrollbar-thin">
        <div class="min-h-full p-3 sm:p-4 md:p-6 pb-20 md:pb-6">
          <div class="max-w-7xl mx-auto">
            <RouterView />
          </div>
        </div>
      </main>
      <!-- Mobile Bottom Navigation -->
      <MobileNav class="md:hidden" />
    </div>
  </div>
</template>
