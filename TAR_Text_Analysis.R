library(tidytext)
library(tidyverse)
library(stringr)
library(rvest)
library(tm)
library(topicmodels)
library(widyr)
library(wordcloud)
library(ggraph)
library(igraph)


urlBase <- sprintf("https://e-discoveryteam.com/tar-course/tar-course-")

myStopWords <- data_frame(word = c("_____", "193", "502", "d", "95", "2.5", "2006", "california", "ralph’s"))

target <- map(1:17, function(i) {
  if (i == 1) {
    paste(urlBase, i, "st-class/", sep = "")
  } else if (i == 2) {
    paste(urlBase, i, "nd-class/", sep = "")
  } else if ( i == 3) {
    paste(urlBase, i, "rd-class/", sep = "")
  } else {
    paste(urlBase, i, "th-class/", sep = "")
  }
})

texts <- map(target, read_html)

text_list <- map(texts, function(i) {
  (html_text(html_nodes(i, ".entry")))
})

text_df <- data_frame(text = unlist(text_list), Article = 1:17)

text_df <- text_df %>% 
  unnest_tokens(word, text)

text_df %>% 
  anti_join(stop_words) %>% 
  count(word, sort = TRUE)

text_sentiment <- text_df %>%
  anti_join(stop_words) %>% 
  inner_join(get_sentiments("bing")) %>% 
  count(word, index = row_number() %/% 104, sentiment) %>% 
  spread(sentiment, n, fill = 0) %>% 
  mutate(sentiment = positive - negative)

ggplot(text_sentiment, aes(index, sentiment, fill = sentiment)) +
  geom_col() +
  geom_hline(aes(yintercept = 0), alpha = 0.23, col = "navy") +
  theme(panel.background = element_blank(),
        text = element_text(family = "mono", color = "navy"),
        axis.ticks = element_blank(),
        axis.text.x = element_blank()) +
  ggtitle("Sentiment by Class ")

article_words <- text_df %>% 
  count(Article, word, sort = TRUE)

total_words <- article_words %>% 
  group_by(Article) %>% 
  summarise(total = sum(n))

article_words <- left_join(article_words, total_words)

article_words

ggplot(article_words, aes(n/total, fill = Article)) +
  geom_histogram(show.legend = FALSE) +
  facet_wrap(~Article, ncol = 4, scales = "free_y") +
  xlim(NA, 0.04)

article_words <- article_words %>% 
  bind_tf_idf(word, Article, n)

article_words %>% 
  mutate(word = str_replace(word, "____", ""))

article_words %>% 
  anti_join(myStopWords) %>% 
  select(-total) %>% 
  arrange(desc(tf_idf)) %>% 
  top_n(20)

plot_article <- article_words %>% 
  anti_join(myStopWords) %>% 
  arrange(desc(tf_idf)) %>% 
  mutate(word = factor(word, levels = rev(unique(word))))

plot_article %>% 
  top_n(20) %>% 
  ggplot(aes(word, tf_idf, fill = factor(Article))) +
  geom_col()+
  scale_fill_discrete(guide = guide_legend(title = "Article")) +
  coord_flip() +
  theme(panel.background = element_blank(),
        text = element_text(family = "mono", color = "navy"),
        axis.ticks = element_blank())

plot_article %>% 
  group_by(Article) %>% 
  top_n(5) %>% 
  ungroup() %>% 
  ggplot(aes(word, tf_idf, fill = factor(Article))) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~Article, ncol = 5, scales = "free") +
    coord_flip() +
    theme(panel.background = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks = element_blank())

text_pairs <- text_df %>% 
  pairwise_count(word, Article, sort = TRUE)
  
set.seed(34)

text_pairs %>% 
  filter(n >= 5) %>% 
  graph_from_data_frame() %>% 
  ggraph(layout = "fr") + 
    geom_edge_link(aes(edge_alpha = n, edge_width = n))
  
