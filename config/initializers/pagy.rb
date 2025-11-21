# frozen_string_literal: true

# Pagy configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy#variables

Pagy::DEFAULT[:limit] = 20       # default items per page
Pagy::DEFAULT[:max_limit] = 100  # max items per page (for security)
