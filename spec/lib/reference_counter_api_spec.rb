# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/reference_counter_api"

describe ReferenceCounterApi do
  before { stub_wiki_validation }

  let(:en_wikipedia) { Wiki.get_or_create(language: 'en', project: 'wikipedia') }
  let(:es_wiktionary) { Wiki.get_or_create(language: 'es', project: 'wiktionary') }
  let(:commons) { Wiki.get_or_create(language: 'commons', project: 'wikimedia') }
  let(:wikidata) { Wiki.get_or_create(language: nil, project: 'wikidata') }
  let(:deleted_rev_id) { [6115106] }
  let(:rev_ids) { [5006940, 5006942, 5006946] }

  it 'raises InvalidProjectError for wikidata' do
    expect do
      described_class.new(wikidata)
    end.to raise_error(described_class::InvalidProjectError)
  end

  it 'raises InvalidProjectError for wikimedia projects (commons, meta, etc.)' do
    expect do
      described_class.new(commons)
    end.to raise_error(described_class::InvalidProjectError)
  end

  context 'when the API returns 200 responses' do
    before do
      stub_wiki_validation
      stub_es_wiktionary_reference_counter_response
    end

    it 'returns the number of references' do
      ref_counter_api = described_class.new(es_wiktionary)
      response = ref_counter_api.get_number_of_references_from_revision_ids rev_ids + deleted_rev_id
      expect(response.dig('5006940', 'num_ref')).to eq(10)
      expect(response.dig('5006940').key?('error')).to eq(false)
      expect(response.dig('5006942', 'num_ref')).to eq(4)
      expect(response.dig('5006942').key?('error')).to eq(false)
      expect(response.dig('5006946', 'num_ref')).to eq(2)
      expect(response.dig('5006946').key?('error')).to eq(false)
      expect(response.dig('6115106', 'num_ref')).to be_nil
      expect(response.dig('6115106').key?('error')).to eq(false)
    end

    it 'records suppressed-content revs on the update service and does not send them to Sentry' do
      update_service = instance_double('UpdateService', record_reference_counter_403: true)
      ref_counter_api = described_class.new(es_wiktionary, update_service)

      expect(update_service).to receive(:record_reference_counter_403).once
      expect(Sentry).not_to receive(:capture_exception)

      ref_counter_api.get_number_of_references_from_revision_ids(rev_ids + deleted_rev_id)
    end
  end

  context 'fails silently' do
    before do
      stub_wiki_validation
    end

    it 'if response is 400 bad request' do
      stub_400_wiki_reference_counter_response
      ref_counter_api = described_class.new(en_wikipedia)
      response = ref_counter_api.get_number_of_references_from_revision_ids rev_ids
      expect(response.dig('5006940', 'num_ref')).to be_nil
      expect(response.dig('5006940').key?('error')).to eq(false)
      expect(response.dig('5006942', 'num_ref')).to be_nil
      expect(response.dig('5006942').key?('error')).to eq(false)
      expect(response.dig('5006946', 'num_ref')).to be_nil
      expect(response.dig('5006946').key?('error')).to eq(false)
    end

    it 'if response is 403 forbidden' do
      stub_403_wiki_reference_counter_response
      ref_counter_api = described_class.new(en_wikipedia)
      response = ref_counter_api.get_number_of_references_from_revision_ids rev_ids
      expect(response.dig('5006940', 'num_ref')).to be_nil
      expect(response.dig('5006940').key?('error')).to eq(false)
      expect(response.dig('5006942', 'num_ref')).to be_nil
      expect(response.dig('5006942').key?('error')).to eq(false)
      expect(response.dig('5006946', 'num_ref')).to be_nil
      expect(response.dig('5006946').key?('error')).to eq(false)
    end

    it 'if response is 404 not found' do
      stub_404_wiki_reference_counter_response
      ref_counter_api = described_class.new(en_wikipedia)
      response = ref_counter_api.get_number_of_references_from_revision_ids rev_ids
      expect(response.dig('5006940', 'num_ref')).to be_nil
      expect(response.dig('5006940').key?('error')).to eq(false)
      expect(response.dig('5006942', 'num_ref')).to be_nil
      expect(response.dig('5006942').key?('error')).to eq(false)
      expect(response.dig('5006946', 'num_ref')).to be_nil
      expect(response.dig('5006946').key?('error')).to eq(false)
    end
  end

  it 'logs the error once if an unexpected error raises several times' do
    reference_counter_api = described_class.new(es_wiktionary)

    stub_request(:any, /.*reference-counter.toolforge.org*/)
      .to_raise(Errno::ETIMEDOUT)

    expect(reference_counter_api).to receive(:log_error).once.with(
      Faraday::TimeoutError,
      update_service: nil,
      sentry_extra: {
         project_code: 'wiktionary',
         language_code: 'es',
         rev_ids: [5006940, 5006942, 5006946],
         error_count: 1
     }
    )
    response = reference_counter_api.get_number_of_references_from_revision_ids rev_ids
    expect(response.dig('5006942', 'num_ref')).to be_nil
    expect(response.dig('5006942', 'error')).not_to be_nil
    expect(response.dig('5006946', 'num_ref')).to be_nil
    expect(response.dig('5006946', 'error')).not_to be_nil
    expect(response.dig('5006940', 'num_ref')).to be_nil
    expect(response.dig('5006940', 'error')).not_to be_nil
  end

  context 'when the API returns non-200 responses' do
    let(:failing_ids) {
      [708326238, 123456789, 987654321, 111222333, 444555666, 777888999, 408326238] }

    # Mock the update service to provide the tags the test expects
    let(:update_service) do
      instance_double('UpdateService',
        update_error_stats: true,
        record_reference_counter_403: true,
        sentry_tags: { update_service_id: 'tag1', course: '/UBA/Mongolia_(second_semester_2026)' }
      )
    end

    let(:subject) { described_class.new(en_wikipedia, update_service) }

    it 'sends separate Sentry logs for each unique non-403 status code' do
      subject.send(:batch_non_200_response_log, 404, { rev_id: 987654321, content: {} })
      subject.send(:batch_non_200_response_log, 400, { rev_id: 111222333, content: {} })
      subject.send(:batch_non_200_response_log, 400, { rev_id: 111222333, content: {} })

      # Expecting two different exceptions to be captured
      expect(Sentry).to receive(:capture_exception).twice
      subject.send(:report_reference_counter_error_to_sentry)
    end
  end

  # Without these, a silent toolforge server blocks the worker indefinitely.
  describe 'toolforge_server connection' do
    let(:conn) { described_class.new(en_wikipedia).send(:toolforge_server) }

    it 'has a finite request timeout' do
      expect(conn.options.timeout).to eq(described_class::REQUEST_TIMEOUT)
      expect(conn.options.timeout).to be > 0
    end

    it 'has a finite open_timeout' do
      expect(conn.options.open_timeout).to eq(described_class::OPEN_TIMEOUT)
      expect(conn.options.open_timeout).to be > 0
    end
  end
end
