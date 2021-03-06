require 'sidekiq/web'

Rails.application.routes.draw do
  use_doorkeeper

  authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
  end

  devise_for :projects
  devise_for :users, :controllers => { registrations: "registrations", :omniauth_callbacks => "callbacks" }

  namespace :admin do
    get :become
  end

  namespace :users_api, default: { format: 'json' } do
    namespace :v1 do
      resources :users, only: [] do
        collection do
          get :current
        end
      end

      resources :commits, only: [] do
        member do
          get :status
        end
      end
    end
  end

  namespace :api, default: { format: 'json' } do
    namespace :v1 do
      resources :projects, only: [] do
        collection do
          get :setup_data
          post :beacon
        end
      end
      resources :test_runs
      resources :test_jobs, only: [] do
        collection do
          patch :bind_next_batch
          patch :batch_update
        end
      end
    end
  end

  get 'oauth/github_callback' => 'oauth#github_callback', as: :github_callback
  get 'oauth/bitbucket_callback' => 'oauth#bitbucket_callback', as: :bitbucket_callback
  get 'oauth/authorize_bitbucket' => 'oauth#authorize_bitbucket', as: :authorize_bitbucket_access
  post 'webhooks/github' => 'webhooks#github', as: :github_webhook
  post 'webhooks/bitbucket' => 'webhooks#bitbucket', as: :bitbucket_webhook

  root to: "dashboard#index"

  get 'invitation/accept' => "user_invitations#accept", as: :accept_user_invitation
  # If you put this in the defaults(project: nil) block above it will erase
  # the "project" param from create action resulting in error.
  resources :projects, only: [:show, :update, :destroy] do
    resource :settings, only: [:show] do
      get :worker_setup
      get :notifications
      resources :project_files, as: :files, path: :files, except: [:edit]
      resources :project_participations, as: :participations, path: :users
    end

    resources :worker_groups, only: [:create, :update, :destroy] do
      member do
        post :reset_ssh_key
      end
    end

    member do
      get :docker_compose
      post :toggle_private
      get :status
    end

    resources :test_runs, path: 'builds' do
      member do
        post :retry
      end
    end

    resources :test_jobs, only: [] do
      put :retry
    end

    resources :tracked_branches, only: [:new, :create, :destroy],
      path: :branches, as: :branches do
      get :fetch_branches, on: :collection
    end

    resources :user_invitations, path: :invitations,
      except: [:index, :show, :update, :edit] do
      member do
        post :resend
      end
    end
  end

  resources :email_submissions, only: :create
  resources :feedback_submissions, only: :create
  resources :project_wizard, only: [:show, :update] do
    get :fetch_repos, on: :member
  end

  resource :dashboard, controller: :dashboard, only: [] do
    member do
      get :github_authorization_required
      get :bitbucket_authorization_required
    end
  end

  post 'live_updates/subscribe' => "live_updates#subscribe",
    as: :live_updates_subscribe

  constraints(format: /xml\.gz/) do
    get 'sitemap' => 'sitemap#show'
  end

  #Using get ... :via => :all allows the error pages to be displayed for any type of request (GET, POST, PUT, etc.).
  get "/403", :to => "errors#access_denied"
  get "/404", :to => "errors#not_found"
  get "/500", :to => "errors#internal_server_error"

  # http://collectiveidea.com/blog/archives/2016/01/12/lets-encrypt-with-a-rails-app-on-heroku/
  get '/.well-known/acme-challenge/:id' => 'pages#letsencrypt'
end
