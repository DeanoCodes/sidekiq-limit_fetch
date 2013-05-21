require 'sidekiq'
require 'celluloid'
require 'sidekiq/fetch'

class Sidekiq::LimitFetch
  require_relative 'limit_fetch/unit_of_work'
  require_relative 'limit_fetch/singleton'
  require_relative 'limit_fetch/queues'
  require_relative 'limit_fetch/local/semaphore'
  require_relative 'limit_fetch/local/selector'
  require_relative 'limit_fetch/global/semaphore'
  require_relative 'limit_fetch/global/selector'
  require_relative 'limit_fetch/global/monitor'
  require_relative 'extensions/queue'

  Sidekiq.options[:fetch] = self

  def self.bulk_requeue(jobs)
    Sidekiq::BasicFetch.bulk_requeue jobs
  end

  def initialize(options)
    Global::Monitor.start! unless options[:local]
    @queues = Queues.new options
  end

  def retrieve_work
    queue, message = fetch_message
    UnitOfWork.new queue, message if message
  end

  private

  def fetch_message
    queue, _ = redis_blpop *@queues.acquire, Sidekiq::Fetcher::TIMEOUT
  ensure
    @queues.release_except queue
  end

  def redis_blpop(*args)
    return if args.size < 2
    Sidekiq.redis {|it| it.blpop *args }
  end
end
