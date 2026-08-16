import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';
import Heading from '@theme/Heading';
import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/getting-started">
            Get Started 🚀
          </Link>
          <span style={{ width: '1rem' }}></span>
          <Link
            className="button button--outline button--secondary button--lg"
            style={{ color: 'white', borderColor: 'white' }}
            to="https://github.com/roshancodespace/byte_me">
            View on GitHub
          </Link>
        </div>
      </div>
    </header>
  );
}

function HomepageFeatures() {
  return (
    <section className="padding-vert--xl">
      <div className="container">
        <div className="row">
          <div className={clsx('col col--4', 'text--center', 'padding-horiz--md')}>
            <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🌍</div>
            <Heading as="h3">Global Queue</Heading>
            <p>Define a max concurrent limit. Enqueue as many tasks as you want, and the orchestrator safely throttles them without memory leaks.</p>
          </div>
          <div className={clsx('col col--4', 'text--center', 'padding-horiz--md')}>
            <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🚀</div>
            <Heading as="h3">Isolate Offloading</Heading>
            <p>Network and disk I/O are fully isolated on background threads, ensuring 60FPS UI performance even during massive 4K video downloads.</p>
          </div>
          <div className={clsx('col col--4', 'text--center', 'padding-horiz--md')}>
            <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🎞️</div>
            <Heading as="h3">Native HLS Plugin</Heading>
            <p>Instantly unlock AES-128 decrypted, multi-threaded .m3u8 stream downloading and stitching through the global orchestrator.</p>
          </div>
        </div>
      </div>
    </section>
  );
}

function HomepageCodeSnippet() {
  return (
    <section className="padding-vert--xl" style={{ backgroundColor: 'var(--ifm-color-emphasis-100)' }}>
      <div className="container">
        <div className="row">
          <div className="col col--8 col--offset-2">
            <Heading as="h2" className="text--center margin-bottom--lg">Zero Boilerplate API</Heading>
            <CodeBlock language="dart" title="lib/main.dart">
              {`import 'package:byte_me/byte_me.dart';
import 'package:byte_me_hls/byte_me_hls.dart';

// 1. Isolate the manager on a background thread
final manager = DownloadManager.isolated(maxConcurrentJobs: 3);

// 2. Queue an encrypted HLS stream instantly!
final hlsJob = manager.addHlsVideo(
  id: 'movie_1',
  m3u8Url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  savePath: '/app/movie.mp4',
  maxConcurrentSegments: 5,
);

// 3. Listen to unified progress!
hlsJob.progressStream.listen((progress) {
  print(progress.formattedPercentage); // "45.2%"
  print(progress.formattedSpeed);      // "2.4 MB/s"
});`}
            </CodeBlock>
          </div>
        </div>
      </div>
    </section>
  );
}

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={`Welcome to ${siteConfig.title}`}
      description="The ultimate, unified download orchestrator for Flutter & Dart.">
      <HomepageHeader />
      <main>
        <HomepageFeatures />
        <HomepageCodeSnippet />
      </main>
    </Layout>
  );
}
